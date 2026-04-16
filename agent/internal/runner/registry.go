package runner

import (
	"fmt"
	"os"
	"sync"
)

// ExecutorFactory creates a new Executor instance.
type ExecutorFactory func() Executor

// ExecutorRegistry maps executor names to factory functions.
type ExecutorRegistry struct {
	mu         sync.RWMutex
	factories  map[string]ExecutorFactory
}

// NewExecutorRegistry creates a registry with default executors registered.
func NewExecutorRegistry() *ExecutorRegistry {
	r := &ExecutorRegistry{
		factories: make(map[string]ExecutorFactory),
	}
	r.Register("shell", func() Executor { return NewShellExecutor() })
	r.Register("script", func() Executor { return NewScriptExecutor() })
	return r
}

// Register adds an executor factory under the given name.
func (r *ExecutorRegistry) Register(name string, factory ExecutorFactory) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.factories[name] = factory
}

// Get returns a new Executor for the given name, or an error if not found.
func (r *ExecutorRegistry) Get(name string) (Executor, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	factory, ok := r.factories[name]
	if !ok {
		return nil, fmt.Errorf("executor %q not registered", name)
	}
	return factory(), nil
}

// DefaultExecutorName returns the executor type from the CLAWDECK_EXECUTOR
// environment variable, falling back to "shell".
func DefaultExecutorName() string {
	if name := os.Getenv("CLAWDECK_EXECUTOR"); name != "" {
		return name
	}
	return "shell"
}
