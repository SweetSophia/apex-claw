// Package envcompat provides a shared helper for reading environment variables
// with primary/legacy key fallback. All Apex Claw env lookups that need to
// support the CLAWDECK_ legacy prefix should use FirstEnv to keep behaviour
// consistent (whitespace trimming, empty-string-as-missing).
package envcompat

import "strings"

// FirstEnv returns the trimmed value of the first non-empty environment
// variable in keys. It trims leading/trailing whitespace from each value and
// treats whitespace-only values as empty. Returns "" if no key yields a value.
//
// This is the single canonical implementation for env-compat lookups across
// the Go agent. Do not create local firstEnv/getCompatEnv/getEnvCompat
// helpers — call this package instead.
func FirstEnv(getenv func(string) string, keys ...string) string {
	for _, key := range keys {
		if raw := getenv(key); raw != "" {
			if v := strings.TrimSpace(raw); v != "" {
				return v
			}
		}
	}
	return ""
}
