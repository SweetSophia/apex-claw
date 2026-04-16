package runner

import (
	"context"
	"strings"
	"testing"

	"github.com/SweetSophia/clawdeck/agent/internal/clawdeck"
)

type testCommandHandler struct {
	result map[string]any
	err    error
}

func (h *testCommandHandler) Handle(ctx context.Context, cmd *clawdeck.Command) (map[string]any, error) {
	return h.result, h.err
}

func TestCommandDispatcherDispatch(t *testing.T) {
	d := NewCommandDispatcher()
	d.Register("health_check", &testCommandHandler{result: map[string]any{"ok": true}})

	result, err := d.Dispatch(context.Background(), &clawdeck.Command{Kind: "health_check"})
	if err != nil {
		t.Fatalf("Dispatch returned error: %v", err)
	}
	if !result["ok"].(bool) {
		t.Fatal("expected ok result")
	}
}

func TestCommandDispatcherUnknownHandler(t *testing.T) {
	d := NewCommandDispatcher()
	_, err := d.Dispatch(context.Background(), &clawdeck.Command{Kind: "missing"})
	if err == nil {
		t.Fatal("expected error")
	}
	if !strings.Contains(err.Error(), "missing") {
		t.Fatalf("expected missing kind in error, got %v", err)
	}
}
