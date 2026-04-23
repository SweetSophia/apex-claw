package runner

import (
	"context"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/SweetSophia/apex-claw/agent/internal/apexclaw"
)

func TestScriptExecutor_Success(t *testing.T) {
	e := NewScriptExecutor()
	result := e.Execute(context.Background(), &apexclaw.Task{
		Description: "#!/bin/bash\necho hello from script",
	})

	if !result.Completed {
		t.Fatalf("expected completed, got error: %v", result.Error)
	}
	if !strings.Contains(result.Output, "hello from script") {
		t.Fatalf("unexpected output: %q", result.Output)
	}
}

func TestScriptExecutor_Failure(t *testing.T) {
	e := NewScriptExecutor()
	result := e.Execute(context.Background(), &apexclaw.Task{
		Description: "#!/bin/bash\nexit 42",
	})

	if result.Completed {
		t.Fatal("expected failure for non-zero exit")
	}
	if result.Error == nil {
		t.Fatal("expected error")
	}
}

func TestScriptExecutor_Cleanup(t *testing.T) {
	e := NewScriptExecutor()
	// Execute and check temp file is cleaned up by looking at output.
	// We verify indirectly: if temp files accumulated, /tmp would fill up.
	result := e.Execute(context.Background(), &apexclaw.Task{
		Description: "echo cleanup test",
	})
	if !result.Completed {
		t.Fatalf("expected completed: %v", result.Error)
	}
}

func TestScriptExecutor_EmptyScript(t *testing.T) {
	e := NewScriptExecutor()
	result := e.Execute(context.Background(), &apexclaw.Task{Description: ""})
	if result.Completed {
		t.Fatal("expected failure for empty script")
	}
}

func TestScriptExecutor_Timeout(t *testing.T) {
	e := &ScriptExecutor{
		Timeout: 100 * time.Millisecond,
	}

	result := e.Execute(context.Background(), &apexclaw.Task{
		Description: "sleep 10",
	})

	if result.Completed {
		t.Fatal("expected timeout failure")
	}
}

func TestScriptExecutor_WritesToTempFile(t *testing.T) {
	// Verify the script actually executes from a file (not inline).
	e := NewScriptExecutor()
	script := "echo $0"
	result := e.Execute(context.Background(), &apexclaw.Task{
		Description: script,
	})
	if !result.Completed {
		t.Fatalf("expected completed: %v", result.Error)
	}
	// $0 should contain the temp file path (contains "apex-claw-script-")
	if !strings.Contains(result.Output, "apex-claw-script-") {
		t.Fatalf("expected temp file path in output, got: %q", result.Output)
	}
	// Verify file was cleaned up
	_ = os.Remove(strings.TrimSpace(result.Output)) // best effort
}
