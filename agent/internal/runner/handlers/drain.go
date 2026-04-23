package handlers

import (
	"context"

	"github.com/SweetSophia/apex-claw/agent/internal/apexclaw"
)

type DrainHandler struct {
	SetDraining func(bool)
}

func (h *DrainHandler) Handle(ctx context.Context, cmd *apexclaw.Command) (map[string]any, error) {
	_ = ctx
	_ = cmd
	if h != nil && h.SetDraining != nil {
		h.SetDraining(true)
	}
	return map[string]any{"draining": true}, nil
}
