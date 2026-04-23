package handlers

import (
	"context"
	"runtime"
	"testing"
	"time"

	"github.com/SweetSophia/apex-claw/agent/internal/apexclaw"
)

func TestHealthCheckHandlerReturnsDiagnostics(t *testing.T) {
	h := &HealthCheckHandler{
		StartTime:      time.Now().Add(-5 * time.Second),
		TaskActiveFunc: func() bool { return true },
	}

	result, err := h.Handle(context.Background(), &apexclaw.Command{Kind: "health_check"})
	if err != nil {
		t.Fatalf("Handle returned error: %v", err)
	}

	if result["goroutines"].(int) < 1 {
		t.Fatal("expected goroutines count")
	}
	if result["go_version"].(string) != runtime.Version() {
		t.Fatalf("unexpected go_version: %v", result["go_version"])
	}
	if result["num_cpu"].(int) != runtime.NumCPU() {
		t.Fatalf("unexpected num_cpu: %v", result["num_cpu"])
	}
	if !result["task_runner_active"].(bool) {
		t.Fatal("expected task_runner_active=true")
	}
	if result["uptime_seconds"].(float64) < 4 {
		t.Fatalf("expected uptime >= 4s, got %v", result["uptime_seconds"])
	}
}
