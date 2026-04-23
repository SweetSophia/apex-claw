package runner

import (
	"context"
	"fmt"
	"sync"

	"github.com/SweetSophia/apex-claw/agent/internal/apexclaw"
)

type CommandHandler interface {
	Handle(ctx context.Context, cmd *apexclaw.Command) (map[string]any, error)
}

type CommandDispatcher struct {
	mu       sync.RWMutex
	handlers map[string]CommandHandler
}

func NewCommandDispatcher() *CommandDispatcher {
	return &CommandDispatcher{handlers: make(map[string]CommandHandler)}
}

func (d *CommandDispatcher) Register(kind string, handler CommandHandler) {
	d.mu.Lock()
	defer d.mu.Unlock()
	d.handlers[kind] = handler
}

func (d *CommandDispatcher) Dispatch(ctx context.Context, cmd *apexclaw.Command) (map[string]any, error) {
	if cmd == nil {
		return nil, fmt.Errorf("command is nil")
	}

	d.mu.RLock()
	handler, ok := d.handlers[cmd.Kind]
	d.mu.RUnlock()
	if !ok {
		return nil, fmt.Errorf("no handler registered for command kind %q", cmd.Kind)
	}

	return handler.Handle(ctx, cmd)
}
