package runner

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/SweetSophia/apex-claw/agent/internal/apexclaw"
)

func TestTaskRunner_DrainingSkipsPoll(t *testing.T) {
	var pollCount int
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		pollCount++
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{}`))
	}))
	defer srv.Close()

	client := apexclaw.NewClient(srv.URL)
	client.SetToken("test-token")

	executor := &noopExecutor{}
	tr := NewTaskRunner(client, 50*time.Millisecond, executor)
	tr.SetDraining(true)

	ctx, cancel := context.WithTimeout(context.Background(), 200*time.Millisecond)
	defer cancel()

	tr.Run(ctx)

	if pollCount > 0 {
		t.Fatalf("expected no polls while draining, got %d", pollCount)
	}
}

func TestTaskRunner_SetDraining(t *testing.T) {
	tr := NewTaskRunner(nil, 0, nil)
	if tr.Draining() {
		t.Fatal("expected false")
	}
	tr.SetDraining(true)
	if !tr.Draining() {
		t.Fatal("expected true")
	}
}

func TestTaskRunner_ActiveTracking(t *testing.T) {
	tr := NewTaskRunner(nil, 0, nil)
	if tr.Active() {
		t.Fatal("expected false initially")
	}
	tr.active.Store(true)
	if !tr.Active() {
		t.Fatal("expected true after store")
	}
}

type noopExecutor struct{}

func (e *noopExecutor) Name() string { return "noop" }
func (e *noopExecutor) Execute(ctx context.Context, task *apexclaw.Task) ExecutionResult {
	return ExecutionResult{Completed: true}
}
