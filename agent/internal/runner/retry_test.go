package runner

import (
	"testing"
	"time"
)

func TestDefaultRetryConfig(t *testing.T) {
	cfg := DefaultRetryConfig()
	if cfg.MaxRetries != 3 {
		t.Fatalf("MaxRetries = %d, want 3", cfg.MaxRetries)
	}
	if cfg.BaseDelay != 5*time.Second {
		t.Fatalf("BaseDelay = %s, want 5s", cfg.BaseDelay)
	}
	if cfg.MaxDelay != 5*time.Minute {
		t.Fatalf("MaxDelay = %s, want 5m", cfg.MaxDelay)
	}
	if cfg.Multiplier != 2.0 {
		t.Fatalf("Multiplier = %f, want 2.0", cfg.Multiplier)
	}
}

func TestBackoffDelayWithinJitterBounds(t *testing.T) {
	cfg := RetryConfig{
		MaxRetries: 3,
		BaseDelay:  10 * time.Second,
		MaxDelay:   time.Minute,
		Multiplier: 2.0,
	}

	cases := []struct {
		attempt int
		base    time.Duration
	}{
		{attempt: 1, base: 10 * time.Second},
		{attempt: 2, base: 20 * time.Second},
		{attempt: 3, base: 40 * time.Second},
	}

	for _, tc := range cases {
		for i := 0; i < 200; i++ {
			got := cfg.BackoffDelay(tc.attempt)
			min := time.Duration(float64(tc.base) * 0.75)
			max := time.Duration(float64(tc.base) * 1.25)
			if got < min || got > max {
				t.Fatalf("attempt %d delay %s out of bounds [%s, %s]", tc.attempt, got, min, max)
			}
		}
	}
}

func TestBackoffDelayCapsAtMaxDelay(t *testing.T) {
	cfg := RetryConfig{
		MaxRetries: 5,
		BaseDelay:  10 * time.Second,
		MaxDelay:   30 * time.Second,
		Multiplier: 3.0,
	}

	for i := 0; i < 200; i++ {
		got := cfg.BackoffDelay(4)
		min := time.Duration(float64(cfg.MaxDelay) * 0.75)
		if got < min || got > cfg.MaxDelay {
			t.Fatalf("capped delay %s out of bounds [%s, %s]", got, min, cfg.MaxDelay)
		}
	}
}
