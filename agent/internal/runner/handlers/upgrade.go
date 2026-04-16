package handlers

import (
	"context"

	"github.com/SweetSophia/clawdeck/agent/internal/clawdeck"
	"github.com/SweetSophia/clawdeck/agent/internal/logging"
)

type UpgradeHandler struct{}

func (h *UpgradeHandler) Handle(ctx context.Context, cmd *clawdeck.Command) (map[string]any, error) {
	_ = ctx
	logging.Global().Info("received upgrade command", map[string]any{"command_id": cmd.ID, "payload": cmd.Payload})
	return map[string]any{
		"upgraded": false,
		"message":  "upgrade not yet implemented",
	}, nil
}
