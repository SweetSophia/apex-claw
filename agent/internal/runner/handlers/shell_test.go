package handlers

import (
	"context"
	"os"
	"strings"
	"testing"

	"github.com/SweetSophia/apex-claw/agent/internal/apexclaw"
)

func TestShellHandlerAllowlistEnforcement(t *testing.T) {
	t.Setenv("APEX_CLAW_SHELL_ALLOWED", "echo")
	h := &ShellHandler{}

	_, err := h.Handle(context.Background(), &apexclaw.Command{Payload: map[string]any{"command": "pwd"}})
	if err == nil {
		t.Fatal("expected allowlist error")
	}
	if !strings.Contains(err.Error(), "not allowed") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestShellHandlerExecution(t *testing.T) {
	_ = os.Setenv("APEX_CLAW_SHELL_ALLOWED", "echo")
	t.Cleanup(func() { os.Unsetenv("APEX_CLAW_SHELL_ALLOWED") })

	h := &ShellHandler{}
	result, err := h.Handle(context.Background(), &apexclaw.Command{Payload: map[string]any{"command": "echo hello", "timeout": 5}})
	if err != nil {
		t.Fatalf("Handle returned error: %v", err)
	}
	if strings.TrimSpace(result["stdout"].(string)) != "hello" {
		t.Fatalf("unexpected stdout: %#v", result["stdout"])
	}
	if result["exit_code"].(int) != 0 {
		t.Fatalf("unexpected exit code: %#v", result["exit_code"])
	}
	if result["stderr"].(string) != "" {
		t.Fatalf("unexpected stderr: %#v", result["stderr"])
	}
}

func TestShellHandlerRejectsDisallowedArguments(t *testing.T) {
	t.Setenv("APEX_CLAW_SHELL_ALLOWED", "df")
	h := &ShellHandler{}

	_, err := h.Handle(context.Background(), &apexclaw.Command{Payload: map[string]any{"command": "df /"}})
	if err == nil {
		t.Fatal("expected argument validation error")
	}
	if !strings.Contains(err.Error(), "only allows the -h flag") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestShellHandlerSupportsSingleQuotedArguments(t *testing.T) {
	t.Setenv("APEX_CLAW_SHELL_ALLOWED", "echo")
	h := &ShellHandler{}

	result, err := h.Handle(context.Background(), &apexclaw.Command{Payload: map[string]any{"command": "echo 'hello world'", "timeout": 5}})
	if err != nil {
		t.Fatalf("Handle returned error: %v", err)
	}
	if strings.TrimSpace(result["stdout"].(string)) != "hello world" {
		t.Fatalf("unexpected stdout: %#v", result["stdout"])
	}
}
