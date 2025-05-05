package configutil

import (
	"os"
	"path/filepath"
	"testing"
)

func TestExpandPath(t *testing.T) {
	home, err := os.UserHomeDir()
	if err != nil {
		t.Fatalf("cannot get home dir: %v", err)
	}

	tests := []struct {
		name       string
		input      string
		wantPrefix string
		wantErr    bool
	}{
		{"tilde path", "~/unit-test", filepath.Join(home, "unit-test"), false},
		{"absolute path", filepath.Join(os.TempDir(), "abs-test"), filepath.Join(os.TempDir(), "abs-test"), false},
		{"empty path", "", "", true},
	}

	for _, tc := range tests {
		got, err := ExpandPath(tc.input)
		if tc.wantErr {
			if err == nil {
				t.Errorf("%s: expected error, got nil", tc.name)
			}
			continue
		}
		if err != nil {
			t.Errorf("%s: unexpected error: %v", tc.name, err)
			continue
		}
		if got != tc.wantPrefix {
			t.Errorf("%s: want %s, got %s", tc.name, tc.wantPrefix, got)
		}
	}
}

func TestGetEnvWithDefault(t *testing.T) {
	const key = "CONFIGUTIL_TEST_ENV"

	// Case: env var set
	if err := os.Setenv(key, "value"); err != nil {
		t.Fatalf("setenv failed: %v", err)
	}
	if got := GetEnvWithDefault(key, "default"); got != "value" {
		t.Errorf("env set: want value, got %s", got)
	}

	// Case: env var unset
	if err := os.Unsetenv(key); err != nil {
		t.Fatalf("unsetenv failed: %v", err)
	}
	if got := GetEnvWithDefault(key, "default"); got != "default" {
		t.Errorf("env unset: want default, got %s", got)
	}
}
