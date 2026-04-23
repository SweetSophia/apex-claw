package orchestrator

import (
	"context"
	"log"

	"github.com/SweetSophia/apex-claw/agent/internal/apexclaw"
)

func HandleDrain(ctx context.Context, cmd *apexclaw.Command) map[string]any {
	log.Printf("handling drain command: %+v", cmd.Payload)
	return map[string]any{
		"success": true,
		"message": "drain initiated",
	}
}

func HandleResume(ctx context.Context, cmd *apexclaw.Command) map[string]any {
	log.Printf("handling resume command: %+v", cmd.Payload)
	return map[string]any{
		"success": true,
		"message": "resumed accepting tasks",
	}
}

func HandleRestart(ctx context.Context, cmd *apexclaw.Command) map[string]any {
	log.Printf("handling restart command: %+v", cmd.Payload)
	return map[string]any{
		"success": false,
		"error":   "restart not implemented in stub handler",
	}
}

func HandleUpgrade(ctx context.Context, cmd *apexclaw.Command) map[string]any {
	log.Printf("handling upgrade command: %+v", cmd.Payload)
	version, _ := cmd.Payload["version"].(string)
	if version == "" {
		return map[string]any{
			"success": false,
			"error":   "version required",
		}
	}
	return map[string]any{
		"success":          false,
		"error":            "upgrade not implemented in stub handler",
		"requested_version": version,
	}
}
