package handlers

import (
	"context"

	"github.com/SweetSophia/clawdeck/agent/internal/clawdeck"
)

type DrainHandler struct {
	SetDraining func(bool)
}

func (h *DrainHandler) Handle(ctx context.Context, cmd *clawdeck.Command) (map[string]any, error) {
	_ = ctx
	_ = cmd
	if h != nil && h.SetDraining != nil {
		h.SetDraining(true)
	}
	return map[string]any{"draining": true}, nil
}
