package cli

import (
	"fmt"
	"io"
	"os"
	"os/signal"
	"strings"
	"syscall"

	api "github.com/aarnphm/dix/overlays/packages/lambda/internal/apiclient"
	"github.com/aarnphm/dix/overlays/packages/lambda/internal/configutil"
	"github.com/aarnphm/dix/overlays/packages/lambda/internal/sshutil"
	log "github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
	"golang.org/x/crypto/ssh"
	"golang.org/x/term"
)

var ConnectCmd = &cobra.Command{
	Use:               "connect <instance_name_or_id>",
	Short:             "Connect via SSH to the specified active instance",
	Args:              cobra.ExactArgs(1),
	ValidArgsFunction: completeInstanceNames,
	RunE: func(cmd *cobra.Command, args []string) error {
		instanceNameOrID := args[0]

		apiKey, _ := cmd.Root().PersistentFlags().GetString("api-key")
		sshKeyPath, _ := cmd.Root().PersistentFlags().GetString("ssh-key-path")
		sshKeyName, _ := cmd.Root().PersistentFlags().GetString("ssh-key-name")
		client, err := api.NewAPIClient(apiKey)
		if err != nil {
			return fmt.Errorf("error initializing API client: %w", err)
		}

		log.Debugf("Looking for instance '%s'", instanceNameOrID)
		var instancesResp api.InstancesResponse
		err = client.Request("GET", "/instances", nil, &instancesResp)
		if err != nil {
			return fmt.Errorf("error fetching instances: %w", err)
		}

		var targetInstance *api.Instance
		// First, try matching by ID
		for i := range instancesResp.Data {
			if instancesResp.Data[i].ID == instanceNameOrID {
				targetInstance = &instancesResp.Data[i]
				log.Debugf("Found instance by ID: %s", instanceNameOrID)
				break
			}
		}
		// If not found by ID, try matching by Name
		if targetInstance == nil {
			log.Debugf("Instance not found by ID '%s', trying by name", instanceNameOrID)
			for i := range instancesResp.Data {
				if instancesResp.Data[i].Name == instanceNameOrID {
					// Check for ambiguity (multiple instances with the same name)
					if targetInstance != nil {
						return fmt.Errorf("multiple instances found with the name '%s'. Please use the unique instance ID instead", instanceNameOrID)
					}
					targetInstance = &instancesResp.Data[i]
					log.Debugf("Found instance by name: %s", instanceNameOrID)
					// Don't break here, continue to check for duplicates
				}
			}
		}

		if targetInstance == nil {
			return fmt.Errorf("no instance found with name or ID '%s'", instanceNameOrID)
		}

		instanceName := targetInstance.Name // Get name for logging/errors
		if targetInstance.Status != "active" {
			return fmt.Errorf("instance '%s' (ID: %s) found, but it is not active (status: '%s')", instanceName, targetInstance.ID, targetInstance.Status)
		}

		if targetInstance.IP == "" || targetInstance.IP == "null" {
			return fmt.Errorf("instance '%s' (ID: %s) is active but does not have an IP address yet. Please try again shortly", instanceName, targetInstance.ID)
		}

		ipAddress := targetInstance.IP
		log.Infof("Connecting to %s at %s", targetInstance.ID, ipAddress)

		// Establish SSH connection using the helper function (with known_hosts check)
		sshClient, err := sshutil.EstablishSSHConnection(ipAddress, sshKeyPath, configutil.RemoteUser, sshKeyName, true)
		if err != nil {
			return fmt.Errorf("failed to establish SSH connection to %s: %w", ipAddress, err)
		}
		defer sshClient.Close()

		// Create a new session
		session, err := sshClient.NewSession()
		if err != nil {
			return fmt.Errorf("failed to create SSH session: %w", err)
		}
		defer session.Close()
		log.Debug("SSH session created.")

		// Set up terminal modes
		modes := ssh.TerminalModes{
			ssh.ECHO:          1,     // enable echoing
			ssh.TTY_OP_ISPEED: 14400, // input speed = 14.4kbaud
			ssh.TTY_OP_OSPEED: 14400, // output speed = 14.4kbaud
		}

		// Get terminal dimensions
		fd := int(os.Stdin.Fd())
		termWidth, termHeight, err := term.GetSize(fd)
		if err != nil {
			log.Warnf("Failed to get terminal size, using default 80x40: %v", err)
			termWidth = 80
			termHeight = 40
		}

		// Request PTY
		if err := session.RequestPty("xterm-256color", termHeight, termWidth, modes); err != nil {
			return fmt.Errorf("request for pseudo terminal failed: %w", err)
		}
		log.Debug("Requested PTY.")

		// Set up stdin, stdout, stderr
		session.Stdin = os.Stdin
		session.Stdout = os.Stdout
		session.Stderr = os.Stderr

		// Put the local terminal into raw mode
		oldState, err := term.MakeRaw(fd)
		if err != nil {
			return fmt.Errorf("failed to put terminal into raw mode: %w", err)
		}
		defer term.Restore(fd, oldState)
		log.Debug("Terminal set to raw mode.")

		// Handle window resize events
		sigwinchCh := make(chan os.Signal, 1)
		quitSIGWINCHListener := make(chan struct{})
		signal.Notify(sigwinchCh, syscall.SIGWINCH)
		go func() {
			defer log.Debugf("SIGWINCH listener goroutine for instance %s has shut down.", targetInstance.ID)
			for {
				select {
				case <-sigwinchCh:
					newTermWidth, newTermHeight, err := term.GetSize(fd)
					if err != nil {
						log.Warnf("Failed to get new terminal size on SIGWINCH for %s: %v", targetInstance.ID, err)
						continue
					}
					// Check if the session is still valid before attempting to send WindowChange
					if session != nil {
						err = session.WindowChange(newTermHeight, newTermWidth)
						if err != nil {
							// if the error is about the session being closed, we can stop.
							if err == io.EOF || strings.Contains(err.Error(), "session closed") {
								log.Debugf("Session closed during WindowChange, SIGWINCH listener for %s stopping.", targetInstance.ID)
								return // Exit goroutine
							}
							log.Warnf("Failed to send window change for %s: %v", targetInstance.ID, err)
						} else {
							log.Debugf("Sent window change for %s: %dx%d", targetInstance.ID, newTermHeight, newTermWidth)
						}
					} else {
						log.Debugf("Session is nil, SIGWINCH listener for %s stopping.", targetInstance.ID)
						return // Exit goroutine if session is already nil
					}
				case <-quitSIGWINCHListener:
					log.Debugf("SIGWINCH listener for %s received quit signal, stopping.", targetInstance.ID)
					return // Exit goroutine
				}
			}
		}()
		defer signal.Stop(sigwinchCh)
		defer close(sigwinchCh)
		defer close(quitSIGWINCHListener) // Ensure the quit channel is closed when ConnectCmd returns

		// Start the remote shell
		if err := session.Shell(); err != nil {
			return fmt.Errorf("failed to start remote shell: %w", err)
		}

		// Wait for the session to finish
		waitErr := session.Wait()
		if waitErr != nil {
			// We expect an error when the session closes, often io.EOF or similar.
			// We don't want to fatalf here unless it's an unexpected error type.
			if waitErr != io.EOF && !strings.Contains(waitErr.Error(), "wait: remote command exited without exit status") && !strings.Contains(waitErr.Error(), "session closed") {
				// Log non-standard exit errors but don't necessarily exit fatally
				log.Warnf("SSH session to '%s' (ID: %s) ended with error: %v", instanceName, targetInstance.ID, waitErr)
				// Stop the SIGWINCH listener explicitly as the session has ended.
				// signal.Stop(sigwinchCh) // defer will handle this, but good to be aware
				return fmt.Errorf("ssh session ended with error: %w", waitErr)
			}
			log.Debugf("SSH session wait finished with expected error: %v", waitErr)
		}
		log.Infof("Disconnected from %s.", targetInstance.ID)
		return nil
	},
}
