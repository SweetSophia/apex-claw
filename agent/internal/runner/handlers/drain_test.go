package handlers

import (
	"context"
	"testing"

	"github.com/SweetSophia/apex-claw/agent/internal/apexclaw"
)

func TestDrainHandlerSetsFlag(t *testing.T) {
	var draining bool
	h := &DrainHandler{SetDraining: func(v bool) { draining = v }}

	result, err := h.Handle(context.Background(), &apexclaw.Command{Kind: "drain"})
	if err != nil {
		t.Fatalf("Handle returned error: %v", err)
	}
	if !draining {
		t.Fatal("expected draining callback to be invoked")
	}
	if !result["draining"].(bool) {
		t.Fatal("expected draining result to be true")
	}
}
