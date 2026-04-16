package runner

import (
	"context"

	"github.com/SweetSophia/clawdeck/agent/internal/clawdeck"
)

// ExecutionResult holds the outcome of a task execution.
type ExecutionResult struct {
	Completed bool
	Error     error
	Output    string
}

// Executor is the interface for task execution backends.
type Executor interface {
	// Name returns the executor identifier (e.g. "shell", "script").
	Name() string
	// Execute runs the given task and returns the result.
	Execute(ctx context.Context, task *clawdeck.Task) ExecutionResult
}
