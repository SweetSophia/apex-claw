package logging

import (
	"bytes"
	"encoding/json"
	"strings"
	"testing"
)

func TestLoggerJSONFormatAndFields(t *testing.T) {
	var buf bytes.Buffer
	logger := NewLogger(&buf, LevelDebug, 42)

	logger.Info("task completed", map[string]any{"task_id": int64(7), "duration_ms": int64(1234)})

	line := strings.TrimSpace(buf.String())
	if line == "" {
		t.Fatal("expected log output")
	}

	var payload map[string]any
	if err := json.Unmarshal([]byte(line), &payload); err != nil {
		t.Fatalf("unmarshal log: %v", err)
	}

	if payload["level"] != "INFO" {
		t.Fatalf("level = %v, want INFO", payload["level"])
	}
	if payload["msg"] != "task completed" {
		t.Fatalf("msg = %v, want task completed", payload["msg"])
	}
	if payload["agent_id"] != float64(42) {
		t.Fatalf("agent_id = %v, want 42", payload["agent_id"])
	}
	if payload["task_id"] != float64(7) {
		t.Fatalf("task_id = %v, want 7", payload["task_id"])
	}
	if payload["duration_ms"] != float64(1234) {
		t.Fatalf("duration_ms = %v, want 1234", payload["duration_ms"])
	}
	if _, ok := payload["ts"]; !ok {
		t.Fatal("missing ts field")
	}
}

func TestLoggerLevelFiltering(t *testing.T) {
	var buf bytes.Buffer
	logger := NewLogger(&buf, LevelWarn, 9)

	logger.Info("skip", nil)
	logger.Warn("keep", map[string]any{"task_id": 1})

	output := strings.TrimSpace(buf.String())
	lines := strings.Split(output, "\n")
	if len(lines) != 1 {
		t.Fatalf("got %d log lines, want 1", len(lines))
	}
	if !strings.Contains(lines[0], "\"level\":\"WARN\"") {
		t.Fatalf("expected WARN log, got %s", lines[0])
	}
}

func TestLoggerFieldSerialization(t *testing.T) {
	var buf bytes.Buffer
	logger := NewLogger(&buf, LevelDebug, 11)

	fields := map[string]any{
		"nested": map[string]any{"executor": "shell"},
		"ok":     true,
	}
	logger.Debug("serialized", fields)

	var payload map[string]any
	if err := json.Unmarshal(bytes.TrimSpace(buf.Bytes()), &payload); err != nil {
		t.Fatalf("unmarshal log: %v", err)
	}

	nested, ok := payload["nested"].(map[string]any)
	if !ok {
		t.Fatalf("nested = %T, want map[string]any", payload["nested"])
	}
	if nested["executor"] != "shell" {
		t.Fatalf("nested.executor = %v, want shell", nested["executor"])
	}
	if payload["ok"] != true {
		t.Fatalf("ok = %v, want true", payload["ok"])
	}
}
