package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"github.com/SweetSophia/clawdeck/agent/internal/clawdeck"
	"github.com/SweetSophia/clawdeck/agent/internal/config"
	"github.com/SweetSophia/clawdeck/agent/internal/runner"
	"github.com/SweetSophia/clawdeck/agent/internal/runner/handlers"
)

var (
	version = "dev"
)

func main() {
	showVersion := flag.Bool("version", false, "show version")
	flag.Parse()

	if *showVersion {
		fmt.Printf("claw-agent %s\n", version)
		os.Exit(0)
	}

	log.Printf("claw-agent %s starting", version)

	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("failed to load config: %v", err)
	}

	client := clawdeck.NewClient(cfg.APIURL)

	agentID, token, err := cfg.LoadPersistedToken()
	if err != nil {
		log.Printf("warning: failed to load persisted token: %v", err)
	}

	if token == "" && cfg.JoinToken == "" {
		log.Fatal("no persisted token found and APEX_CLAW_JOIN_TOKEN / CLAWDECK_JOIN_TOKEN not set")
	}

	if token != "" {
		client.SetToken(token)
		client.SetAgentID(agentID)
		log.Printf("using persisted token for agent %d", agentID)
	} else {
		log.Printf("registering agent with join token")
		resp, err := client.Register(cfg.JoinToken, clawdeck.AgentInfo{
			Name:     cfg.AgentInfo.Name,
			Hostname: cfg.AgentInfo.Hostname,
			HostUID:  cfg.AgentInfo.HostUID,
			Platform: cfg.AgentInfo.Platform,
			Version:  version,
			Tags:     cfg.AgentInfo.Tags,
			Metadata: cfg.AgentInfo.Metadata,
		})
		if err != nil {
			log.Fatalf("failed to register: %v", err)
		}

		agentID = resp.Agent.ID
		log.Printf("registered agent id=%d name=%s", resp.Agent.ID, resp.Agent.Name)

		if err := cfg.SaveToken(resp.Agent.ID, resp.AgentToken); err != nil {
			log.Printf("warning: failed to persist token: %v", err)
		}
	}

	// Graceful shutdown context: cancels on SIGINT/SIGTERM.
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	sigCtx, sigCancel := signal.NotifyContext(ctx, syscall.SIGINT, syscall.SIGTERM)
	defer sigCancel()

	registry := runner.NewExecutorRegistry()
	executorName := runner.DefaultExecutorName()
	executor, err := registry.Get(executorName)
	if err != nil {
		log.Fatalf("failed to create executor %q: %v", executorName, err)
	}
	log.Printf("using executor: %s", executor.Name())

	heartbeatRunner := runner.NewHeartbeatRunner(client, agentID, cfg.HeartbeatDelay)
	taskRunner := runner.NewTaskRunner(client, cfg.TaskPollDelay, executor)
	commandDispatcher := runner.NewCommandDispatcher()
	commandDispatcher.Register("drain", &handlers.DrainHandler{SetDraining: taskRunner.SetDraining})
	commandDispatcher.Register("health_check", &handlers.HealthCheckHandler{StartTime: time.Now(), TaskActiveFunc: taskRunner.Active})
	commandDispatcher.Register("shell", &handlers.ShellHandler{})
	commandDispatcher.Register("config_reload", &handlers.ConfigReloadHandler{})
	commandDispatcher.Register("upgrade", &handlers.UpgradeHandler{})
	commandRunner := runner.NewCommandRunner(client, cfg.CommandPollDelay, commandDispatcher)

	// Wire task-active callback so heartbeat metadata includes runner state.
	heartbeatRunner.SetTaskActiveFunc(taskRunner.Active)

	errChan := make(chan error, 3)

	var wg sync.WaitGroup

	wg.Add(1)
	go func() {
		defer wg.Done()
		if err := heartbeatRunner.Run(sigCtx); err != nil && !errors.Is(err, context.Canceled) {
			errChan <- fmt.Errorf("heartbeat: %w", err)
		}
	}()

	wg.Add(1)
	go func() {
		defer wg.Done()
		if err := taskRunner.Run(sigCtx); err != nil && !errors.Is(err, context.Canceled) {
			errChan <- fmt.Errorf("task: %w", err)
		}
	}()

	wg.Add(1)
	go func() {
		defer wg.Done()
		if err := commandRunner.Run(sigCtx); err != nil && !errors.Is(err, context.Canceled) {
			errChan <- fmt.Errorf("command: %w", err)
		}
	}()

	// Wait for signal, server-initiated shutdown, or runner error.
	select {
	case <-sigCtx.Done():
		log.Printf("received shutdown signal")
	case req := <-heartbeatRunner.ShutdownCh:
		log.Printf("server requested %s", req.Action)
	case err := <-errChan:
		log.Printf("runner error: %v", err)
	}

	// Enter drain mode so task runner stops polling.
	taskRunner.SetDraining(true)
	heartbeatRunner.SetDraining(true)

	// Wait for the current task to finish (with timeout).
	shutdownTimeout := 30 * time.Second
	if taskRunner.Active() {
		log.Printf("waiting up to %s for active task to complete", shutdownTimeout)
		done := make(chan struct{})
		go func() {
			for taskRunner.Active() {
				time.Sleep(100 * time.Millisecond)
			}
			close(done)
		}()

		select {
		case <-done:
			log.Printf("active task completed")
		case <-time.After(shutdownTimeout):
			log.Printf("shutdown timeout reached, forcing exit")
		}
	}

	cancel()
	log.Printf("shutting down...")

	// Wait for goroutines with timeout.
	done := make(chan struct{})
	go func() {
		wg.Wait()
		close(done)
	}()

	select {
	case <-done:
		log.Printf("all goroutines exited cleanly")
	case <-time.After(10 * time.Second):
		log.Printf("goroutine shutdown timed out")
	}

	log.Printf("graceful shutdown complete")
}
