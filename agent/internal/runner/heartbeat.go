package runner

import (
	"context"
	"log"
	"runtime"
	"sync"
	"time"

	"github.com/SweetSophia/clawdeck/agent/internal/clawdeck"
)

const (
	defaultHeartbeatInterval = 30 * time.Second
	minHeartbeatInterval     = 5 * time.Second
	maxHeartbeatInterval     = 5 * time.Minute
)

// ShutdownRequest is emitted via the ShutdownCh channel when the server
// requests a restart or shutdown.
type ShutdownRequest struct {
	Action string // "restart" or "shutdown"
}

// HeartbeatRunner periodically sends heartbeat requests to the ClawDeck API
// and processes desired_state actions from the server.
type HeartbeatRunner struct {
	client   *clawdeck.Client
	interval time.Duration
	agentID  int64

	mu         sync.Mutex
	lastStatus string
	draining   bool
	startTime  time.Time

	// taskActiveFunc is called to check whether the task runner has an
	// in-flight task. Set via SetTaskActiveFunc before starting the runner.
	taskActiveFunc func() bool

	// ShutdownCh emits a ShutdownRequest when the server requests restart or
	// shutdown. The consumer (main.go) is responsible for orchestrating the
	// actual shutdown. The channel is buffered(1).
	ShutdownCh chan ShutdownRequest
}

func NewHeartbeatRunner(client *clawdeck.Client, agentID int64, interval time.Duration) *HeartbeatRunner {
	return &HeartbeatRunner{
		client:     client,
		interval:   normalizeHeartbeatInterval(interval),
		agentID:    agentID,
		startTime:  time.Now(),
		ShutdownCh: make(chan ShutdownRequest, 1),
	}
}

// SetTaskActiveFunc registers a callback that reports whether the task runner
// is currently executing a task. Must be called before Run.
func (h *HeartbeatRunner) SetTaskActiveFunc(fn func() bool) {
	h.taskActiveFunc = fn
}

// Draining returns whether the agent is in drain mode.
func (h *HeartbeatRunner) Draining() bool {
	h.mu.Lock()
	defer h.mu.Unlock()
	return h.draining
}

// SetDraining sets the drain mode flag.
func (h *HeartbeatRunner) SetDraining(v bool) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.draining = v
}

func (h *HeartbeatRunner) Interval() time.Duration {
	h.mu.Lock()
	defer h.mu.Unlock()
	return h.interval
}

func (h *HeartbeatRunner) setIntervalFromServer(seconds int) {
	if seconds <= 0 {
		return
	}

	newInterval := normalizeHeartbeatInterval(time.Duration(seconds) * time.Second)

	h.mu.Lock()
	oldInterval := h.interval
	if oldInterval == newInterval {
		h.mu.Unlock()
		return
	}
	h.interval = newInterval
	h.mu.Unlock()

	log.Printf("heartbeat interval updated from server: %s -> %s", oldInterval, newInterval)
}

func normalizeHeartbeatInterval(interval time.Duration) time.Duration {
	if interval <= 0 {
		interval = defaultHeartbeatInterval
	}
	if interval < minHeartbeatInterval {
		return minHeartbeatInterval
	}
	if interval > maxHeartbeatInterval {
		return maxHeartbeatInterval
	}
	return interval
}

func (h *HeartbeatRunner) Run(ctx context.Context) error {
	h.sendHeartbeat(ctx)

	for {
		wait := h.Interval()
		timer := time.NewTimer(wait)

		select {
		case <-ctx.Done():
			if !timer.Stop() {
				<-timer.C
			}
			log.Printf("heartbeat runner stopping: %v", ctx.Err())
			return ctx.Err()
		case <-timer.C:
			h.sendHeartbeat(ctx)
		}
	}
}

func (h *HeartbeatRunner) sendHeartbeat(ctx context.Context) {
	metadata := h.collectMetadata()
	status := "online"
	if h.lastStatus != "" {
		status = h.lastStatus
	}

	resp, err := h.client.Heartbeat(h.agentID, status, metadata)
	if err != nil {
		log.Printf("heartbeat failed: %v", err)
		return
	}

	log.Printf("heartbeat ok: agent status=%s desired_state=%s",
		resp.Agent.Status, resp.DesiredState.Action)
	if resp.TokenRotationRequired {
		log.Printf("heartbeat warning: token rotation required for agent %d", h.agentID)
	}
	if resp.HeartbeatIntervalSeconds > 0 {
		h.setIntervalFromServer(resp.HeartbeatIntervalSeconds)
	}

	h.handleDesiredState(resp.DesiredState.Action)
}

func (h *HeartbeatRunner) handleDesiredState(action string) {
	switch action {
	case "drain":
		log.Printf("desired state: entering drain mode")
		h.SetDraining(true)
	case "restart":
		log.Printf("desired state: restart requested")
		h.emitShutdown(ShutdownRequest{Action: "restart"})
	case "shutdown":
		log.Printf("desired state: shutdown requested")
		h.emitShutdown(ShutdownRequest{Action: "shutdown"})
	case "none", "":
		// no action
	default:
		log.Printf("desired state: unknown action %q, ignoring", action)
	}
}

func (h *HeartbeatRunner) emitShutdown(req ShutdownRequest) {
	select {
	case h.ShutdownCh <- req:
	default:
		log.Printf("shutdown channel full, dropping %s request", req.Action)
	}
}

func (h *HeartbeatRunner) collectMetadata() map[string]any {
	var memStats runtime.MemStats
	runtime.ReadMemStats(&memStats)

	h.mu.Lock()
	isDraining := h.draining
	h.mu.Unlock()

	var taskActive bool
	if h.taskActiveFunc != nil {
		taskActive = h.taskActiveFunc()
	}

	return map[string]any{
		"goroutines":         runtime.NumGoroutine(),
		"go_version":         runtime.Version(),
		"alloc_mb":           memStats.Alloc / 1024 / 1024,
		"sys_mb":             memStats.Sys / 1024 / 1024,
		"num_cpu":            runtime.NumCPU(),
		"task_runner_active": taskActive,
		"draining":           isDraining,
		"uptime_seconds":     time.Since(h.startTime).Truncate(time.Second).Seconds(),
	}
}

func (h *HeartbeatRunner) SetStatus(status string) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.lastStatus = status
}
