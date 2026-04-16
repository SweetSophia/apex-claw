package runner

import (
	"math"
	"math/rand"
	"time"
)

type RetryConfig struct {
	MaxRetries int
	BaseDelay  time.Duration
	MaxDelay   time.Duration
	Multiplier float64
}

func DefaultRetryConfig() RetryConfig {
	return RetryConfig{
		MaxRetries: 3,
		BaseDelay:  5 * time.Second,
		MaxDelay:   5 * time.Minute,
		Multiplier: 2.0,
	}
}

func (c RetryConfig) BackoffDelay(attempt int) time.Duration {
	if attempt < 1 {
		attempt = 1
	}

	base := c.BaseDelay
	if base <= 0 {
		base = 5 * time.Second
	}
	maxDelay := c.MaxDelay
	if maxDelay <= 0 {
		maxDelay = 5 * time.Minute
	}
	multiplier := c.Multiplier
	if multiplier <= 0 {
		multiplier = 2.0
	}

	delay := float64(base)
	for i := 1; i < attempt; i++ {
		delay *= multiplier
		if time.Duration(delay) >= maxDelay {
			delay = float64(maxDelay)
			break
		}
	}

	if delay > float64(maxDelay) {
		delay = float64(maxDelay)
	}

	jitterFactor := 0.75 + rand.Float64()*0.5
	jittered := time.Duration(math.Round(delay * jitterFactor))
	if jittered < 0 {
		return 0
	}
	if jittered > maxDelay {
		return maxDelay
	}
	return jittered
}
