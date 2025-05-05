package cli

import (
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
	Use:               "connect <instance_name>",
	Short:             "Connect via SSH to the specified active instance",
	Args:              cobra.ExactArgs(1),
	ValidArgsFunction: completeInstanceNames,
	Run: func(cmd *cobra.Command, args []string) {
		instanceName := args[0]

		client, err := api.NewAPIClient()
		if err != nil {
			log.Fatalf("Error initializing API client: %v", err)
		}

		log.Infof("Looking for instance '%s'", instanceName)
		var instancesResp api.InstancesResponse
		err = client.Request("GET", "/instances", nil, &instancesResp)
		if err != nil {
			log.Fatalf("Error fetching instances: %v", err)
		}

		var targetInstance *api.Instance
		for i := range instancesResp.Data {
			if instancesResp.Data[i].Name == instanceName {
				targetInstance = &instancesResp.Data[i]
				break
			}
		}

		if targetInstance == nil {
			log.Fatalf("Error: No instance found with name '%s'.", instanceName)
		}

		if targetInstance.Status != "active" {
			log.Fatalf("Error: Instance '%s' found, but it is not active (status: '%s'.", instanceName, targetInstance.Status)
		}

		if targetInstance.IP == "" || targetInstance.IP == "null" {
			log.Fatalf("Error: Instance '%s' is active but does not have an IP address yet. Please try again shortly.", instanceName)
		}

		ipAddress := targetInstance.IP
		log.Infof("Connecting to instance '%s' (%s)", instanceName, ipAddress)

		// Establish SSH connection using the helper function (with known_hosts check)
		sshClient, err := sshutil.EstablishSSHConnection(ipAddress, configutil.DefaultSSHKeyPath, configutil.RemoteUser, true)
		if err != nil {
			log.Fatalf("Failed to establish SSH connection: %v", err)
		}
		defer sshClient.Close()

		// Create a new session
		session, err := sshClient.NewSession()
		if err != nil {
			log.Fatalf("Failed to create SSH session: %v", err)
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
			log.Fatalf("Request for pseudo terminal failed: %v", err)
		}
		log.Debug("Requested PTY.")

		// Set up stdin, stdout, stderr
		session.Stdin = os.Stdin
		session.Stdout = os.Stdout
		session.Stderr = os.Stderr

		// Put the local terminal into raw mode
		oldState, err := term.MakeRaw(fd)
		if err != nil {
			log.Fatalf("Failed to put terminal into raw mode: %v", err)
		}
		defer term.Restore(fd, oldState)
		log.Debug("Terminal set to raw mode.")

		// Start the remote shell
		if err := session.Shell(); err != nil {
			log.Fatalf("Failed to start remote shell: %v", err)
		}

		// Wait for the session to finish
		if err := session.Wait(); err != nil {
			// We expect an error when the session closes, often io.EOF or similar.
			// We don't want to fatalf here unless it's an unexpected error type.
			if err != io.EOF && !strings.Contains(err.Error(), "wait: remote command exited without exit status") && !strings.Contains(err.Error(), "session closed") {
				// Log non-standard exit errors but don't necessarily exit fatally
				log.Warnf("SSH session ended with error: %v", err)
			}
		}
	},
}
