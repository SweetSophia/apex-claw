package envcompat

import "testing"

func TestFirstEnv(t *testing.T) {
	tests := []struct {
		name   string
		env    map[string]string
		keys   []string
		expect string
	}{
		{
			name:   "no keys returns empty",
			env:    map[string]string{},
			keys:   []string{"MISSING"},
			expect: "",
		},
		{
			name:   "primary key wins",
			env:    map[string]string{"APEX_FOO": "bar", "LEGACY_FOO": "old"},
			keys:   []string{"APEX_FOO", "LEGACY_FOO"},
			expect: "bar",
		},
		{
			name:   "falls back to legacy",
			env:    map[string]string{"LEGACY_FOO": "old"},
			keys:   []string{"APEX_FOO", "LEGACY_FOO"},
			expect: "old",
		},
		{
			name:   "trims whitespace",
			env:    map[string]string{"KEY": "  value  "},
			keys:   []string{"KEY"},
			expect: "value",
		},
		{
			name:   "whitespace-only treated as empty",
			env:    map[string]string{"KEY": "   "},
			keys:   []string{"KEY"},
			expect: "",
		},
		{
			name:   "empty string treated as missing",
			env:    map[string]string{"PRIMARY": "", "LEGACY": "fallback"},
			keys:   []string{"PRIMARY", "LEGACY"},
			expect: "fallback",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			getenv := func(key string) string { return tt.env[key] }
			got := FirstEnv(getenv, tt.keys...)
			if got != tt.expect {
				t.Errorf("FirstEnv() = %q, want %q", got, tt.expect)
			}
		})
	}
}
