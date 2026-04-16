package runner

import (
	"testing"
)

func TestNewExecutorRegistry_Defaults(t *testing.T) {
	r := NewExecutorRegistry()

	for _, name := range []string{"shell", "script"} {
		e, err := r.Get(name)
		if err != nil {
			t.Fatalf("expected executor %q to be registered: %v", name, err)
		}
		if e.Name() != name {
			t.Fatalf("expected name %q, got %q", name, e.Name())
		}
	}
}

func TestExecutorRegistry_GetUnknown(t *testing.T) {
	r := NewExecutorRegistry()
	_, err := r.Get("nonexistent")
	if err == nil {
		t.Fatal("expected error for unknown executor")
	}
}

func TestExecutorRegistry_RegisterCustom(t *testing.T) {
	r := NewExecutorRegistry()
	r.Register("custom", func() Executor {
		return &ShellExecutor{}
	})

	e, err := r.Get("custom")
	if err != nil {
		t.Fatalf("expected custom executor: %v", err)
	}
	if e.Name() != "shell" {
		t.Fatalf("unexpected name: %s", e.Name())
	}
}

func TestDefaultExecutorName_Fallback(t *testing.T) {
	name := DefaultExecutorName()
	if name != "shell" {
		t.Fatalf("expected default 'shell', got %q", name)
	}
}
