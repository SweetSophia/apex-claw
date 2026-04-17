package handlers

import (
	"context"
	"runtime"
	"time"

	"github.com/SweetSophia/clawdeck/agent/internal/clawdeck"
)

type HealthCheckHandler struct {
	StartTime      time.Time
	TaskActiveFunc func() bool
}

func (h *HealthCheckHandler) Handle(ctx context.Context, cmd *clawdeck.Command) (map[string]any, error) {
	_ = ctx
	_ = cmd

	var memStats runtime.MemStats
	runtime.ReadMemStats(&memStats)

	taskActive := false
	if h != nil && h.TaskActiveFunc != nil {
		taskActive = h.TaskActiveFunc()
	}

	startTime := time.Now()
	if h != nil && !h.StartTime.IsZero() {
		startTime = h.StartTime
	}

	return map[string]any{
		"goroutines":         runtime.NumGoroutine(),
		"alloc_mb":           memStats.Alloc / 1024 / 1024,
		"sys_mb":             memStats.Sys / 1024 / 1024,
		"uptime_seconds":     time.Since(startTime).Truncate(time.Second).Seconds(),
		"task_runner_active": taskActive,
		"go_version":         runtime.Version(),
		"num_cpu":            runtime.NumCPU(),
	}, nil
}
