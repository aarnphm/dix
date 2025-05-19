package sshutil

import (
	"bytes"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"github.com/aarnphm/detachtools/overlays/packages/lambda/internal/configutil"
	log "github.com/sirupsen/logrus"
	"golang.org/x/crypto/ssh"
	"golang.org/x/crypto/ssh/knownhosts"
	"golang.org/x/term"
)

// getSSHKey reads and parses an SSH private key, handling passphrases.
func getSSHKey(keyPath string) (ssh.Signer, error) {
	expandedPath, err := configutil.ExpandPath(keyPath)
	if err != nil {
		return nil, fmt.Errorf("expanding SSH key path '%s': %w", keyPath, err)
	}
	log.Debugf("Attempting to read SSH private key from: %s", expandedPath)
	keyBytes, err := os.ReadFile(expandedPath)
	if err != nil {
		return nil, fmt.Errorf("reading SSH key file '%s': %w", expandedPath, err)
	}
	log.Debugf("Read %d bytes from key file.", len(keyBytes))

	signer, err := ssh.ParsePrivateKey(keyBytes)
	if err != nil {
		log.Debugf("Parsing private key failed initially: %v", err)
		// Check if it needs a passphrase
		var passphraseMissingErr *ssh.PassphraseMissingError
		if errors.As(err, &passphraseMissingErr) { // Use errors.As for type checking
			log.Infof("SSH key %s seems to be encrypted.", expandedPath)
			fmt.Printf("Enter passphrase for key %s: ", expandedPath)
			bytePassword, err := term.ReadPassword(int(syscall.Stdin))
			if err != nil {
				return nil, fmt.Errorf("reading passphrase: %w", err)
			}
			fmt.Println() // Add newline after password entry
			log.Debug("Attempting to parse key with passphrase.")
			signer, err = ssh.ParsePrivateKeyWithPassphrase(keyBytes, bytePassword)
			if err != nil {
				return nil, fmt.Errorf("parsing private key with passphrase: %w", err)
			}
			log.Debug("Successfully parsed key with passphrase.")
		} else {
			return nil, fmt.Errorf("parsing private key '%s': %w", expandedPath, err)
		}
	} else {
		log.Debugf("Successfully parsed unencrypted private key.")
	}

	// Log the public key fingerprint being used
	if signer != nil {
		pubKey := signer.PublicKey()
		fingerprint := ssh.FingerprintSHA256(pubKey)
		log.Debugf("Using public key %s with fingerprint: %s", pubKey.Type(), fingerprint)
	}

	return signer, nil
}

// RunRemoteCommand executes a command on the remote host via SSH.
func RunRemoteCommand(client *ssh.Client, command string) error {
	session, err := client.NewSession()
	if err != nil {
		return fmt.Errorf("failed to create SSH session: %w", err)
	}
	defer session.Close()

	// Pipe remote stdout and stderr to local stdout/stderr
	session.Stdout = os.Stdout
	session.Stderr = os.Stderr

	log.Debugf("Running remote command: %s", command)
	err = session.Run(command) // Use Run for non-interactive commands
	if err != nil {
		// Check if it's an ExitError to potentially get more details
		var exitError *ssh.ExitError
		if errors.As(err, &exitError) {
			return fmt.Errorf("remote command '%s' failed with exit status %d: %w", command, exitError.ExitStatus(), err)
		}
		return fmt.Errorf("failed to run remote command '%s': %w", command, err)
	}
	return nil
}

// copySingleFileInternal handles the SCP process for a single file.
// expandedLocalPath must be an existing file. localFileInfo is its os.FileInfo.
// remotePath is the full target path for the file on the remote server.
func copySingleFileInternal(client *ssh.Client, expandedLocalPath string, remotePath string, localFileInfo os.FileInfo) error {
	if localFileInfo.IsDir() {
		// This function should not be called for directories directly by external callers.
		return fmt.Errorf("copySingleFileInternal called with a directory: '%s', this should be handled by directory-specific copy logic", expandedLocalPath)
	}

	fileBytes, err := os.ReadFile(expandedLocalPath)
	if err != nil {
		return fmt.Errorf("reading local file '%s': %w", expandedLocalPath, err)
	}

	content := fileBytes
	perms := fmt.Sprintf("%04o", localFileInfo.Mode().Perm())
	filename := filepath.Base(remotePath)
	directory := filepath.Dir(remotePath)

	// Ensure remote target directory for the file exists
	if directory != "." && directory != "/" { // Avoid "mkdir -p ." or "mkdir -p /"
		mkdirCmd := fmt.Sprintf("mkdir -p %s", directory)
		if err := RunRemoteCommand(client, mkdirCmd); err != nil {
			log.Warnf("Failed to ensure remote directory %s exists for file copy (might be okay): %v", directory, err)
		}
	}

	session, err := client.NewSession()
	if err != nil {
		return fmt.Errorf("failed to create SSH session for file copy: %w", err)
	}
	defer session.Close()

	stdin, err := session.StdinPipe()
	if err != nil {
		return fmt.Errorf("failed to get stdin pipe: %w", err)
	}

	go func() {
		defer stdin.Close()
		fmt.Fprintf(stdin, "C%s %d %s\n", perms, len(content), filename)
		stdin.Write([]byte(content))
		fmt.Fprint(stdin, "\x00")
	}()

	remoteCmd := fmt.Sprintf("scp -qt %s", directory)
	log.Debugf("Copying local file '%s' (%d bytes, perm: %s) to remote '%s' via `scp`", expandedLocalPath, len(content), perms, remotePath)

	var stderrBuf bytes.Buffer
	session.Stderr = &stderrBuf

	err = session.Run(remoteCmd)
	if err != nil {
		stderrStr := strings.TrimSpace(stderrBuf.String())
		if stderrStr != "" {
			return fmt.Errorf("failed to run remote scp command '%s' for '%s': %w. Stderr: %s", remoteCmd, remotePath, err, stderrStr)
		}
		return fmt.Errorf("failed to run remote scp command '%s' for '%s': %w", remoteCmd, remotePath, err)
	}

	log.Debugf("Successfully copied '%s' to '%s'", expandedLocalPath, remotePath)
	return nil
}

// CopyFileToRemote copies a single local file to the remote host.
// remoteFilePath is the full path where the file should be saved on the remote.
func CopyFileToRemote(client *ssh.Client, localFilePath, remoteFilePath string) error {
	expandedLocalPath, err := configutil.ExpandPath(localFilePath)
	if err != nil {
		return fmt.Errorf("expanding local file path '%s': %w", localFilePath, err)
	}

	fileInfo, err := os.Stat(expandedLocalPath)
	if err != nil {
		if os.IsNotExist(err) {
			log.Warnf("Local file '%s' does not exist, skipping copy.", expandedLocalPath)
			return nil // Not a fatal error if the source file doesn't exist
		}
		return fmt.Errorf("stat local file '%s': %w", expandedLocalPath, err)
	}

	if fileInfo.IsDir() {
		return fmt.Errorf("local path '%s' is a directory, expected a file. Use CopyDirToRemote for directories", expandedLocalPath)
	}

	return copySingleFileInternal(client, expandedLocalPath, remoteFilePath, fileInfo)
}

// CopyDirToRemote copies the contents of a local directory to a specified remote directory.
// remoteDestDirPath is the path on the remote server where the contents of localDirPath will be placed.
func CopyDirToRemote(client *ssh.Client, localDirPath, remoteDestDirPath string) error {
	expandedLocalDirPath, err := configutil.ExpandPath(localDirPath)
	if err != nil {
		return fmt.Errorf("expanding local directory path '%s': %w", localDirPath, err)
	}

	dirInfo, err := os.Stat(expandedLocalDirPath)
	if err != nil {
		if os.IsNotExist(err) {
			log.Warnf("Local directory '%s' does not exist, skipping copy.", expandedLocalDirPath)
			return nil
		}
		return fmt.Errorf("stat local directory '%s': %w", expandedLocalDirPath, err)
	}

	if !dirInfo.IsDir() {
		return fmt.Errorf("local path '%s' is not a directory, expected a directory. Use CopyFileToRemote for files", expandedLocalDirPath)
	}

	log.Debugf("Copying local directory '%s' contents to remote directory '%s'", expandedLocalDirPath, remoteDestDirPath)

	// Ensure the base remote destination directory exists.
	err = RunRemoteCommand(client, fmt.Sprintf("mkdir -p %s", remoteDestDirPath))
	if err != nil {
		return fmt.Errorf("failed to create base remote directory '%s': %w", remoteDestDirPath, err)
	}

	return filepath.WalkDir(expandedLocalDirPath, func(currentLocalItemPath string, d os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return fmt.Errorf("error walking local path '%s': %w", currentLocalItemPath, walkErr)
		}

		relativePath, err := filepath.Rel(expandedLocalDirPath, currentLocalItemPath)
		if err != nil {
			return fmt.Errorf("failed to get relative path for '%s' from base '%s': %w", currentLocalItemPath, expandedLocalDirPath, err)
		}

		currentRemoteItemPath := filepath.Join(remoteDestDirPath, relativePath)

		if d.IsDir() {
			// If it's the root of the walk (relativePath is "."), it's already created by mkdir -p above.
			// For other subdirectories, create them.
			if relativePath != "." {
				log.Debugf("Creating remote directory: %s", currentRemoteItemPath)
				mkDirCmd := fmt.Sprintf("mkdir -p %s", currentRemoteItemPath)
				if err := RunRemoteCommand(client, mkDirCmd); err != nil {
					// Log warning but continue, as it might exist or not be critical for subsequent file copies
					log.Warnf("Failed to create remote subdirectory %s (might be okay): %v", currentRemoteItemPath, err)
				}
			}
		} else { // It's a file
			itemInfo, statErr := d.Info()
			if statErr != nil {
				return fmt.Errorf("failed to get FileInfo for '%s': %w", currentLocalItemPath, statErr)
			}
			log.Debugf("Copying file %s to %s", currentLocalItemPath, currentRemoteItemPath)
			copyErr := copySingleFileInternal(client, currentLocalItemPath, currentRemoteItemPath, itemInfo)
			if copyErr != nil {
				return fmt.Errorf("failed to copy file '%s' to '%s': %w", currentLocalItemPath, currentRemoteItemPath, copyErr)
			}
		}
		return nil
	})
}

// CopyContentToRemote copies byte content to a remote file using SCP protocol over SSH.
func CopyContentToRemote(client *ssh.Client, content []byte, remotePath string, perms string) error {
	filename := filepath.Base(remotePath)
	directory := filepath.Dir(remotePath)

	// Validate perms format
	if len(perms) != 4 {
		log.Warnf("Invalid permissions format '%s' provided for CopyContentToRemote, using default '0644'", perms)
		perms = "0644"
	}

	// Ensure remote directory exists (optional, add if needed)
	mkdirCmd := fmt.Sprintf("mkdir -p %s", directory)
	if err := RunRemoteCommand(client, mkdirCmd); err != nil {
		log.Warnf("Failed to ensure remote directory %s exists (might be okay): %v", directory, err)
	}

	session, err := client.NewSession()
	if err != nil {
		return fmt.Errorf("failed to create SSH session for content copy: %w", err)
	}
	defer session.Close()

	stdin, err := session.StdinPipe()
	if err != nil {
		return fmt.Errorf("failed to get stdin pipe: %w", err)
	}

	go func() {
		defer stdin.Close()
		fmt.Fprintf(stdin, "C%s %d %s\n", perms, len(content), filename)
		stdin.Write([]byte(content))
		fmt.Fprint(stdin, "\x00")
	}()

	remoteCmd := fmt.Sprintf("scp -qt %s", directory)
	log.Infof("Copying %d bytes of content to remote '%s' via `scp`", len(content), remotePath)

	// Capture stderr for better error reporting
	var stderrBuf bytes.Buffer
	session.Stderr = &stderrBuf

	err = session.Run(remoteCmd)
	if err != nil {
		stderrStr := strings.TrimSpace(stderrBuf.String())
		if stderrStr != "" {
			return fmt.Errorf("failed to run remote scp command '%s' for '%s': %w. Stderr: %s", remoteCmd, remotePath, err, stderrStr)
		}
		return fmt.Errorf("failed to run remote scp command '%s' for '%s': %w", remoteCmd, remotePath, err)
	}
	log.Debugf("Successfully copied content to '%s'", remotePath)
	return nil
}

// EstablishSSHConnection dials and configures an SSH client connection.
func EstablishSSHConnection(ipAddress, sshKeyPath, user, sshKeyName string, useKnownHosts bool) (*ssh.Client, error) {
	// Get SSH key signer using the local function
	signer, err := getSSHKey(sshKeyPath)
	if err != nil {
		return nil, fmt.Errorf("failed to get SSH key from '%s': %w", sshKeyPath, err)
	}

	// Configure HostKeyCallback
	var hostKeyCallback ssh.HostKeyCallback
	if useKnownHosts {
		knownHostsPath, err := configutil.ExpandPath("~/.ssh/known_hosts")
		if err != nil {
			return nil, fmt.Errorf("failed to expand known_hosts path: %w", err)
		}
		callback, err := knownhosts.New(knownHostsPath)
		if err != nil {
			if os.IsNotExist(err) {
				log.Warnf("known_hosts file '%s' not found. Allowing first connection (insecure). Consider connecting manually once.", knownHostsPath)
				// Allow first connection if known_hosts doesn't exist - less secure
				hostKeyCallback = ssh.InsecureIgnoreHostKey()
			} else {
				return nil, fmt.Errorf("failed to read known_hosts file '%s': %w", knownHostsPath, err)
			}
		} else {
			log.Debugf("Using known_hosts file: %s", knownHostsPath)
			hostKeyCallback = callback
		}
	} else {
		log.Warn("Host key checking is disabled (InsecureIgnoreHostKey).")
		hostKeyCallback = ssh.InsecureIgnoreHostKey() // Use insecure for setup or when explicitly disabled
	}

	// Configure SSH client
	sshConfig := &ssh.ClientConfig{
		User: user,
		Auth: []ssh.AuthMethod{
			ssh.PublicKeys(signer),
		},
		HostKeyCallback: hostKeyCallback,
		Timeout:         30 * time.Second, // Connection timeout
	}
	log.Debugf("Attempting SSH auth to %s with user: %s, Key Type: %s", ipAddress, sshConfig.User, signer.PublicKey().Type())

	// Dial the SSH server
	serverAddr := fmt.Sprintf("%s:22", ipAddress)
	log.Debugf("Dialing SSH server %s", serverAddr)
	sshClient, err := ssh.Dial("tcp", serverAddr, sshConfig)
	if err != nil {
		// Specific error handling for knownhosts missing key
		var keyErr *knownhosts.KeyError
		if useKnownHosts && errors.As(err, &keyErr) && len(keyErr.Want) > 0 {
			knownHostsPath, _ := configutil.ExpandPath("~/.ssh/known_hosts") // Ignore error as we checked earlier
			log.Errorf("SSH host key verification failed for %s.", ipAddress)
			log.Errorf("The host key presented by the server is not in '%s'.", knownHostsPath)
			log.Infof("Server offered key types: %v", keyErr.Want) // Log offered key types
			log.Infof("Please connect manually using 'ssh %s@%s' once to add the host key, then try again.", user, ipAddress)
			// Return a distinct error message
			return nil, fmt.Errorf("host key verification failed: key mismatch or not found in known_hosts (%w)", err)
		}
		// Handle other potential dial errors (timeout, connection refused, auth failed etc.)
		if strings.Contains(err.Error(), "unable to authenticate") {
			log.Errorf("SSH authentication failed for user %s. Check private key ('%s') and ensure corresponding public key ('%s') is added to Lambda Cloud.", user, sshKeyPath, sshKeyName)
			return nil, fmt.Errorf("SSH authentication failed: %w", err)
		}
		if strings.Contains(err.Error(), "connection refused") {
			log.Errorf("SSH connection to %s refused. Is the instance running and SSH accessible?", serverAddr)
			return nil, fmt.Errorf("SSH connection refused: %w", err)
		}
		// Generic dial error
		return nil, fmt.Errorf("failed to dial SSH server %s: %w", serverAddr, err)
	}
	log.Infof("SSH connection established successfully to %s@%s", user, ipAddress)
	return sshClient, nil
}
