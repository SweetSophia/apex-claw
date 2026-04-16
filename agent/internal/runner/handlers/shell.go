package handlers

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"

	"github.com/SweetSophia/clawdeck/agent/internal/clawdeck"
)

const defaultShellAllowlist = "ls,cat,pwd,echo,whoami,date,df,free,uptime,top,ps"

type ShellHandler struct{}

func (h *ShellHandler) Handle(ctx context.Context, cmd *clawdeck.Command) (map[string]any, error) {
	command, _ := cmd.Payload["command"].(string)
	command = strings.TrimSpace(command)
	if command == "" {
		return nil, fmt.Errorf("shell command is required")
	}

	parts := strings.Fields(command)
	if len(parts) == 0 {
		return nil, fmt.Errorf("shell command is required")
	}

	binary := parts[0]
	if !isShellCommandAllowed(binary) {
		return nil, fmt.Errorf("shell command %q not allowed", binary)
	}

	timeout := shellTimeoutFromPayload(cmd.Payload)
	ctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()

	execCmd := exec.CommandContext(ctx, binary, parts[1:]...)
	var stdout, stderr bytes.Buffer
	execCmd.Stdout = &stdout
	execCmd.Stderr = &stderr

	err := execCmd.Run()
	exitCode := 0
	if execCmd.ProcessState != nil {
		exitCode = execCmd.ProcessState.ExitCode()
	}

	result := map[string]any{
		"stdout":    stdout.String(),
		"stderr":    stderr.String(),
		"exit_code": exitCode,
	}
	if err != nil {
		return result, fmt.Errorf("shell command failed: %w", err)
	}

	return result, nil
}

func isShellCommandAllowed(binary string) bool {
	for _, allowed := range shellAllowedCommands() {
		if binary == allowed {
			return true
		}
	}
	return false
}

func shellAllowedCommands() []string {
	value := os.Getenv("CLAWDECK_SHELL_ALLOWED")
	if strings.TrimSpace(value) == "" {
		value = defaultShellAllowlist
	}

	parts := strings.Split(value, ",")
	allowed := make([]string, 0, len(parts))
	for _, part := range parts {
		part = strings.TrimSpace(part)
		if part != "" {
			allowed = append(allowed, part)
		}
	}
	return allowed
}

func shellTimeoutFromPayload(payload map[string]any) time.Duration {
	const (
		defaultTimeout = 30 * time.Second
		maxTimeout     = 120 * time.Second
	)

	seconds := 30.0
	switch v := payload["timeout"].(type) {
	case float64:
		seconds = v
	case int:
		seconds = float64(v)
	case int64:
		seconds = float64(v)
	case jsonNumber:
		if parsed, err := strconv.ParseFloat(string(v), 64); err == nil {
			seconds = parsed
		}
	case string:
		if parsed, err := strconv.ParseFloat(strings.TrimSpace(v), 64); err == nil {
			seconds = parsed
		}
	}

	if seconds <= 0 {
		return defaultTimeout
	}
	if seconds > 120 {
		return maxTimeout
	}
	return time.Duration(seconds * float64(time.Second))
}

type jsonNumber string
