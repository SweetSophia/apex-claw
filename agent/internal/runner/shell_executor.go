package runner

import (
	"bytes"
	"context"
	"fmt"
	"os/exec"
	"strings"
	"time"

	"github.com/SweetSophia/apex-claw/agent/internal/apexclaw"
)

// ShellExecutor executes single shell commands from task descriptions.
// Commands are split on whitespace; the first element is matched against
// the AllowedCommands allowlist. An empty allowlist denies all commands.
type ShellExecutor struct {
	AllowedCommands []string
	Timeout         time.Duration
}

// NewShellExecutor creates a ShellExecutor with sensible defaults.
func NewShellExecutor() *ShellExecutor {
	return &ShellExecutor{
		AllowedCommands: []string{},
		Timeout:         5 * time.Minute,
	}
}

func (s *ShellExecutor) Name() string { return "shell" }

func (s *ShellExecutor) Execute(ctx context.Context, task *apexclaw.Task) ExecutionResult {
	command := strings.TrimSpace(task.Description)
	if command == "" {
		return ExecutionResult{
			Completed: false,
			Error:     fmt.Errorf("shell executor: empty command"),
		}
	}

	parts := strings.Fields(command)
	if len(parts) == 0 {
		return ExecutionResult{
			Completed: false,
			Error:     fmt.Errorf("shell executor: empty command"),
		}
	}

	binary := parts[0]

	// Enforce allowlist.
	if !s.commandAllowed(binary) {
		return ExecutionResult{
			Completed: false,
			Error:     fmt.Errorf("shell executor: command %q not in allowlist", binary),
		}
	}

	// Validate binary exists in PATH before execution
	resolvedPath, err := exec.LookPath(binary)
	if err != nil {
		return ExecutionResult{
			Completed: false,
			Error:     fmt.Errorf("shell executor: command %q not found in PATH", binary),
		}
	}

	// Apply timeout.
	if s.Timeout > 0 {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, s.Timeout)
		defer cancel()
	}

	cmd := exec.CommandContext(ctx, resolvedPath, parts[1:]...)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err = cmd.Run()
	output := stdout.String()
	if stderrStr := stderr.String(); stderrStr != "" {
		if output != "" {
			output += "\n"
		}
		output += stderrStr
	}

	if err != nil {
		return ExecutionResult{
			Completed: false,
			Error:     fmt.Errorf("shell executor: %w\n%s", err, output),
			Output:    output,
		}
	}

	return ExecutionResult{
		Completed: true,
		Output:    output,
	}
}

func (s *ShellExecutor) commandAllowed(binary string) bool {
	for _, allowed := range s.AllowedCommands {
		if allowed == binary {
			return true
		}
	}
	return false
}
