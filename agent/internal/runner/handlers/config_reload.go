package handlers

import (
	"context"
	"os"

	"github.com/SweetSophia/clawdeck/agent/internal/clawdeck"
	"github.com/SweetSophia/clawdeck/agent/internal/logging"
)

// ConfigReloadHandler reports current environment configuration.
// Note: Since agent config is entirely env-based, this handler reports
// current values rather than re-reading changed values. A true hot-reload
// would require restarting the agent process.
type ConfigReloadHandler struct{}

func (h *ConfigReloadHandler) Handle(ctx context.Context, cmd *clawdeck.Command) (map[string]any, error) {
	_ = ctx
	_ = cmd

	cfg := map[string]any{
		"executor":  os.Getenv("CLAWDECK_EXECUTOR"),
		"log_level": os.Getenv("CLAWDECK_LOG_LEVEL"),
	}
	logging.Global().Info("config status reported", cfg)

	return map[string]any{
		"reloaded": true,
		"config":   cfg,
	}, nil
}
