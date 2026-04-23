package runner

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/SweetSophia/apex-claw/agent/internal/apexclaw"
)

func TestShellExecutor_AllowedCommand(t *testing.T) {
	e := &ShellExecutor{
		AllowedCommands: []string{"echo"},
		Timeout:         10 * time.Second,
	}

	result := e.Execute(context.Background(), &apexclaw.Task{
		Description: "echo hello world",
	})

	if !result.Completed {
		t.Fatalf("expected completed, got error: %v", result.Error)
	}
	if !strings.Contains(result.Output, "hello world") {
		t.Fatalf("unexpected output: %q", result.Output)
	}
}

func TestShellExecutor_DeniedCommand(t *testing.T) {
	e := &ShellExecutor{
		AllowedCommands: []string{"ls"},
		Timeout:         10 * time.Second,
	}

	result := e.Execute(context.Background(), &apexclaw.Task{
		Description: "rm -rf /",
	})

	if result.Completed {
		t.Fatal("expected failure for denied command")
	}
	if result.Error == nil {
		t.Fatal("expected error for denied command")
	}
	if !strings.Contains(result.Error.Error(), "not in allowlist") {
		t.Fatalf("unexpected error: %v", result.Error)
	}
}

func TestShellExecutor_Timeout(t *testing.T) {
	e := &ShellExecutor{
		AllowedCommands: []string{"sleep"},
		Timeout:         100 * time.Millisecond,
	}

	result := e.Execute(context.Background(), &apexclaw.Task{
		Description: "sleep 10",
	})

	if result.Completed {
		t.Fatal("expected timeout failure")
	}
	if result.Error == nil {
		t.Fatal("expected error from timeout")
	}
}

func TestShellExecutor_ContextCancellation(t *testing.T) {
	e := &ShellExecutor{
		AllowedCommands: []string{"sleep"},
		Timeout:         0, // rely on context only
	}

	ctx, cancel := context.WithCancel(context.Background())
	go func() {
		time.Sleep(100 * time.Millisecond)
		cancel()
	}()

	result := e.Execute(ctx, &apexclaw.Task{
		Description: "sleep 10",
	})

	if result.Completed {
		t.Fatal("expected cancellation failure")
	}
}

func TestShellExecutor_EmptyCommand(t *testing.T) {
	e := NewShellExecutor()
	result := e.Execute(context.Background(), &apexclaw.Task{Description: ""})
	if result.Completed {
		t.Fatal("expected failure for empty command")
	}
}
