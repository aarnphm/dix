package cli

import (
	"fmt"
	"io"
	"os"
	"strings"

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
		instanceIdentifier := args[0]

		apiKey, _ := cmd.Root().PersistentFlags().GetString("api-key")
		client, err := api.NewAPIClient(apiKey)
		if err != nil {
			return fmt.Errorf("failed to create API client: %w", err)
		}

		log.Debugf("Looking for instance '%s'", instanceIdentifier)
		var instancesResp api.InstancesResponse
		err = client.Request("GET", "/instances", nil, &instancesResp)
		if err != nil {
			return fmt.Errorf("error fetching instances: %w", err)
		}

		var targetInstance *api.Instance
		// First, try matching by ID
		for i := range instancesResp.Data {
			if instancesResp.Data[i].ID == instanceIdentifier {
				targetInstance = &instancesResp.Data[i]
				log.Debugf("Found instance by ID: %s", instanceIdentifier)
				break
			}
		}
		// If not found by ID, try matching by Name
		if targetInstance == nil {
			log.Debugf("Instance not found by ID '%s', trying by name", instanceIdentifier)
			for i := range instancesResp.Data {
				if instancesResp.Data[i].Name == instanceIdentifier {
					// Check for ambiguity (multiple instances with the same name)
					if targetInstance != nil {
						return fmt.Errorf("multiple instances found with the name '%s'. Please use the unique instance ID instead", instanceIdentifier)
					}
					targetInstance = &instancesResp.Data[i]
					log.Debugf("Found instance by name: %s", instanceIdentifier)
					// Don't break here, continue to check for duplicates
				}
			}
		}

		if targetInstance == nil {
			return fmt.Errorf("no instance found with name or ID '%s'", instanceIdentifier)
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
		sshClient, err := sshutil.EstablishSSHConnection(ipAddress, configutil.DefaultSSHKeyPath, configutil.RemoteUser, true)
		if err != nil {
			return fmt.Errorf("failed to establish SSH connection: %w", err)
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
				return fmt.Errorf("ssh session ended with error: %w", waitErr)
			}
			log.Debugf("SSH session wait finished with expected error: %v", waitErr)
		}
		return nil
	},
}
