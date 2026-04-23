package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/SweetSophia/apex-claw/agent/internal/apexclaw"
	"github.com/SweetSophia/apex-claw/agent/internal/envcompat"
)

const defaultShellAllowlist = "pwd,echo,whoami,date,df,free,uptime"

type ShellHandler struct{}

func (h *ShellHandler) Handle(ctx context.Context, cmd *apexclaw.Command) (map[string]any, error) {
	command, _ := cmd.Payload["command"].(string)
	command = strings.TrimSpace(command)
	if command == "" {
		return nil, fmt.Errorf("shell command is required")
	}

	parts, err := parseShellCommand(command)
	if err != nil || len(parts) == 0 {
		return nil, fmt.Errorf("shell command is required")
	}

	binary := parts[0]
	if err := validateShellCommand(binary, parts[1:]); err != nil {
		return nil, err
	}
	if !isShellCommandAllowed(binary) {
		return nil, fmt.Errorf("shell command %q not allowed", binary)
	}

	// Validate binary exists in PATH before execution
	resolvedPath, err := exec.LookPath(binary)
	if err != nil {
		return nil, fmt.Errorf("shell command %q not found in PATH", binary)
	}

	timeout := shellTimeoutFromPayload(cmd.Payload)
	ctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()

	execCmd := exec.CommandContext(ctx, resolvedPath, parts[1:]...)
	var stdout, stderr bytes.Buffer
	execCmd.Stdout = &stdout
	execCmd.Stderr = &stderr

	err = execCmd.Run()
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

func validateShellCommand(binary string, args []string) error {
	if strings.ContainsAny(binary, `/\`) || filepath.Base(binary) != binary {
		return fmt.Errorf("shell command %q not allowed", binary)
	}

	switch binary {
	case "pwd", "whoami", "date", "uptime":
		if len(args) > 0 {
			return fmt.Errorf("shell command %q does not accept arguments", binary)
		}
	case "df", "free":
		for _, arg := range args {
			if arg != "-h" {
				return fmt.Errorf("shell command %q only allows the -h flag", binary)
			}
		}
	case "echo":
		for _, arg := range args {
			if strings.ContainsAny(arg, "\x00\n\r") {
				return fmt.Errorf("shell command %q contains unsupported characters", binary)
			}
		}
	}

	return nil
}

func shellAllowedCommands() []string {
	value := envcompat.FirstEnv(os.Getenv, "APEX_CLAW_SHELL_ALLOWED", "CLAWDECK_SHELL_ALLOWED")
	if value == "" {
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
	case json.Number:
		if parsed, err := v.Float64(); err == nil {
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

// parseShellCommand splits a command string respecting single and double quoted segments.
func parseShellCommand(input string) ([]string, error) {
	var parts []string
	var current strings.Builder
	quoteChar := byte(0)

	for i := 0; i < len(input); i++ {
		ch := input[i]
		switch {
		case ch == '"' || ch == '\'':
			if quoteChar == 0 {
				quoteChar = ch
			} else if quoteChar == ch {
				quoteChar = 0
			} else {
				current.WriteByte(ch)
			}
		case ch == ' ' && quoteChar == 0:
			if current.Len() > 0 {
				parts = append(parts, current.String())
				current.Reset()
			}
		default:
			current.WriteByte(ch)
		}
	}

	if current.Len() > 0 {
		parts = append(parts, current.String())
	}

	if quoteChar != 0 {
		return nil, fmt.Errorf("unclosed quote in command")
	}

	return parts, nil
}
