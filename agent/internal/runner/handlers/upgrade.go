package handlers

import (
	"context"

	"github.com/SweetSophia/clawdeck/agent/internal/clawdeck"
	"github.com/SweetSophia/clawdeck/agent/internal/logging"
)

// UpgradeHandler is a stub for future agent self-upgrade capability.
// Phase 3 intentionally leaves this as a placeholder — actual upgrade
// requires a package manager or deployment pipeline integration.
type UpgradeHandler struct{}

func (h *UpgradeHandler) Handle(ctx context.Context, cmd *clawdeck.Command) (map[string]any, error) {
	_ = ctx
	logging.Global().Info("received upgrade command (stub)", map[string]any{"command_id": cmd.ID, "payload": cmd.Payload})
	return map[string]any{
		"upgraded": false,
		"message":  "upgrade not yet implemented",
	}, nil
}
