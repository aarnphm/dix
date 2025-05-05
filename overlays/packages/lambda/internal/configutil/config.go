package configutil

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// Constants related to configuration and defaults
const (
	DefaultRegion = "us-south-3"
	SSHKeyName    = "aaron-mbp16"
	RemoteUser    = "ubuntu"
	// TODO: Consider removing hardcoded password
	RemotePassword    = "toor"
	DefaultSSHKeyPath = "~/.ssh/id_ed25519-paperspace"
	BitwardenNoteName = "pat-lambda"
)

// ExpandPath expands the tilde (~) prefix in a path to the user's home directory.
func ExpandPath(path string) (string, error) {
	if path == "" {
		return "", fmt.Errorf("path cannot be empty")
	}
	if strings.HasPrefix(path, "~/") {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", fmt.Errorf("getting current user: %w", err)
		}
		return filepath.Join(home, path[2:]), nil
	}
	// Handle absolute paths or paths starting without ~/
	return filepath.Abs(path)
}

// GetEnvWithDefault retrieves an environment variable or returns a default value.
func GetEnvWithDefault(key, defaultValue string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return defaultValue
}
