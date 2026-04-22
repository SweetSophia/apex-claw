package runner

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"os/exec"
	"time"

	"github.com/SweetSophia/clawdeck/agent/internal/clawdeck"
)

const maxScriptSize = 1 * 1024 * 1024 // 1MB

// ScriptExecutor executes multi-line bash scripts from task descriptions.
// Scripts are written to a temporary file, executed with /bin/bash, then cleaned up.
type ScriptExecutor struct {
	AllowedCommands []string // optional top-level command allowlist (empty = allow all scripts)
	Timeout         time.Duration
}

// NewScriptExecutor creates a ScriptExecutor with sensible defaults.
func NewScriptExecutor() *ScriptExecutor {
	return &ScriptExecutor{
		AllowedCommands: []string{},
		Timeout:         5 * time.Minute,
	}
}

func (s *ScriptExecutor) Name() string { return "script" }

func (s *ScriptExecutor) Execute(ctx context.Context, task *clawdeck.Task) ExecutionResult {
	script := task.Description
	if script == "" {
		return ExecutionResult{
			Completed: false,
			Error:     fmt.Errorf("script executor: empty script"),
		}
	}

	if len(script) > maxScriptSize {
		return ExecutionResult{
			Completed: false,
			Error:     fmt.Errorf("script executor: script exceeds maximum size of %d bytes", maxScriptSize),
		}
	}

	// Write script to temp file.
	tmpFile, err := os.CreateTemp("", "apex-claw-script-*.sh")
	if err != nil {
		return ExecutionResult{
			Completed: false,
			Error:     fmt.Errorf("script executor: creating temp file: %w", err),
		}
	}
	tmpPath := tmpFile.Name()
	defer os.Remove(tmpPath)

	if _, err := tmpFile.WriteString(script); err != nil {
		tmpFile.Close()
		return ExecutionResult{
			Completed: false,
			Error:     fmt.Errorf("script executor: writing script: %w", err),
		}
	}
	tmpFile.Close()

	// Make executable.
	if err := os.Chmod(tmpPath, 0700); err != nil {
		return ExecutionResult{
			Completed: false,
			Error:     fmt.Errorf("script executor: chmod: %w", err),
		}
	}

	// Apply timeout.
	if s.Timeout > 0 {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, s.Timeout)
		defer cancel()
	}

	cmd := exec.CommandContext(ctx, "/bin/bash", tmpPath)
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
			Error:     fmt.Errorf("script executor: %w\n%s", err, output),
			Output:    output,
		}
	}

	return ExecutionResult{
		Completed: true,
		Output:    output,
	}
}
