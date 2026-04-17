package runner

import (
	"context"
	"fmt"
	"time"

	"github.com/SweetSophia/clawdeck/agent/internal/clawdeck"
	"github.com/SweetSophia/clawdeck/agent/internal/logging"
)

type CommandRunner struct {
	client     *clawdeck.Client
	interval   time.Duration
	dispatcher *CommandDispatcher
}

func NewCommandRunner(client *clawdeck.Client, interval time.Duration, dispatcher *CommandDispatcher) *CommandRunner {
	if interval == 0 {
		interval = 5 * time.Second
	}

	if client != nil {
		logging.InitLogger(client.AgentID())
	}

	return &CommandRunner{
		client:     client,
		interval:   interval,
		dispatcher: dispatcher,
	}
}

func (c *CommandRunner) Run(ctx context.Context) error {
	ticker := time.NewTicker(c.interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			logging.Global().Info("command runner stopping", map[string]any{"error": ctx.Err().Error()})
			return ctx.Err()
		case <-ticker.C:
			c.pollAndHandle(ctx)
		}
	}
}

func (c *CommandRunner) pollAndHandle(ctx context.Context) {
	cmd, err := c.client.GetNextCommand()
	if err != nil {
		logging.Global().Error("failed to get next command", map[string]any{"error": err.Error()})
		return
	}
	if cmd == nil {
		return
	}

	logger := logging.Global()
	logger.Info("received command", map[string]any{"command_id": cmd.ID, "kind": cmd.Kind, "state": cmd.State})

	if _, err := c.ackWithRetry(ctx, cmd.ID); err != nil {
		logger.Error("failed to ack command", map[string]any{"command_id": cmd.ID, "error": err.Error()})
		return
	}

	result, err := c.dispatcher.Dispatch(ctx, cmd)
	if err != nil {
		logger.Error("command handler failed", map[string]any{"command_id": cmd.ID, "kind": cmd.Kind, "error": err.Error()})
		result = map[string]any{
			"success": false,
			"error":   err.Error(),
		}
	}

	if result == nil {
		result = map[string]any{}
	}

	if _, ok := result["success"]; !ok {
		result["success"] = err == nil
	}

	if _, err := c.client.CompleteCommand(cmd.ID, result); err != nil {
		logger.Error("failed to complete command", map[string]any{"command_id": cmd.ID, "error": err.Error()})
		return
	}

	logger.Info("completed command", map[string]any{"command_id": cmd.ID, "kind": cmd.Kind, "success": result["success"]})
}

func (c *CommandRunner) ackWithRetry(ctx context.Context, commandID int64) (*clawdeck.Command, error) {
	var lastErr error
	backoff := 200 * time.Millisecond

	for attempt := 0; attempt < 3; attempt++ {
		resp, err := c.client.AckCommand(commandID)
		if err == nil {
			return resp, nil
		}
		lastErr = err

		if attempt == 2 {
			break
		}

		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-time.After(backoff):
		}
		backoff *= 2
	}

	return nil, fmt.Errorf("ack command after retries: %w", lastErr)
}

func commandResultError(message string, err error) map[string]any {
	result := map[string]any{"success": false, "error": message}
	if err != nil {
		result["error"] = fmt.Sprintf("%s: %v", message, err)
	}
	return result
}
