package cli

import (
	"bytes"
	_ "embed"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"text/template"

	api "github.com/aarnphm/dix/overlays/packages/lambda/internal/apiclient"
	"github.com/aarnphm/dix/overlays/packages/lambda/internal/configutil"
	"github.com/aarnphm/dix/overlays/packages/lambda/internal/sshutil"
	log "github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
)

//go:embed setup_remote.sh.in
var remoteSetupScriptTemplate string

type remoteSetupParams struct {
	RemoteUser     string
	RemotePassword string
	GhToken        string
}

var SetupCmd = &cobra.Command{
	Use:               "setup <instance_name>",
	Short:             "Run the setup process on the specified active instance",
	Args:              cobra.ExactArgs(1),
	ValidArgsFunction: completeInstanceNames,
	Run: func(cmd *cobra.Command, args []string) {
		// Check if Bitwarden session exists
		if os.Getenv("BW_SESSION") == "" {
			log.Fatal("Bitwarden vault is locked. Please unlock it first (e.g., run 'bw unlock').")
		}

		instanceName := args[0]

		// 1. Find Instance
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
			log.Fatalf("Error: Instance '%s' found, but it is not active (status: '%s'. Cannot setup.", instanceName, targetInstance.Status)
		}
		if targetInstance.IP == "" || targetInstance.IP == "null" {
			log.Fatalf("Error: Instance '%s' is active but does not have an IP address. Cannot setup yet.", instanceName)
		}
		ipAddress := targetInstance.IP
		log.Infof("Preparing setup for instance '%s' (%s)", instanceName, ipAddress)

		// 2. Get GitHub Token from Bitwarden
		log.Info("Retrieving GitHub token from Bitwarden")
		bwCmd := exec.Command("bw", "get", "notes", configutil.BitwardenNoteName)
		ghTokenBytes, err := bwCmd.Output()
		if err != nil {
			log.Error("Failed to execute 'bw get notes'. Is Bitwarden CLI installed, logged in, and unlocked?")
			if exitErr, ok := err.(*exec.ExitError); ok {
				log.Errorf("Bitwarden CLI stderr: %s", string(exitErr.Stderr))
			}
			log.Fatalf("Error running bitwarden command: %v", err)
		}
		ghToken := strings.TrimSpace(string(ghTokenBytes))
		if ghToken == "" {
			log.Fatalf("Failed to retrieve GitHub token (item note '%s') from Bitwarden. Is the note populated?", configutil.BitwardenNoteName)
		}
		log.Info("GitHub token retrieved successfully.")

		// 3. Establish SSH Connection (without strict known_hosts check for setup)
		log.Infof("Establishing SSH connection to %s@%s", configutil.RemoteUser, ipAddress)
		sshClient, err := sshutil.EstablishSSHConnection(ipAddress, configutil.DefaultSSHKeyPath, configutil.RemoteUser, true)
		if err != nil {
			log.Fatalf("Failed to establish SSH connection: %v", err)
		}
		defer sshClient.Close()
		log.Info("SSH connection established.")

		// 4. Copy necessary files
		filesToCopy := map[string]string{
			configutil.GetEnvWithDefault("BW_PASS_FILE", "~/bw.pass"):                               "~/bw.pass",
			configutil.GetEnvWithDefault("SSH_ID_FILE", "~/.ssh/id_ed25519-github"):                 "~/.ssh/id_ed25519-github",
			configutil.GetEnvWithDefault("YATAI_CONFIG_FILE", "~/.local/share/bentoml/.yatai.yaml"): "~/.yatai.yaml",
			configutil.GetEnvWithDefault("GPG_PRIVATE_KEY_FILE", "~/gpg-private-lambdalabs.key"):    "~/gpg-private-lambdalabs.key",
		}
		for local, remote := range filesToCopy {
			expandedLocal, err := configutil.ExpandPath(local)
			if err != nil {
				log.Warnf("Could not expand local path '%s', skipping copy: %v", local, err)
				continue
			}
			if _, err := os.Stat(expandedLocal); os.IsNotExist(err) {
				log.Warnf("Local file '%s' (expanded: '%s') does not exist, skipping copy.", local, expandedLocal)
				continue
			}

			err = sshutil.CopyFileToRemote(sshClient, expandedLocal, remote)
			if err != nil {
				log.Fatalf("Failed to copy file '%s' to '%s': %v", expandedLocal, remote, err)
			}
		}

		// 5. Render and copy setup script
		log.Info("Rendering remote setup script")
		params := remoteSetupParams{
			RemoteUser:     configutil.RemoteUser,
			RemotePassword: configutil.RemotePassword,
			GhToken:        ghToken,
		}
		tmpl, err := template.New("remoteScript").Parse(remoteSetupScriptTemplate)
		if err != nil {
			log.Fatalf("Failed to parse remote script template: %v", err)
		}
		var scriptBuf bytes.Buffer
		if err := tmpl.Execute(&scriptBuf, params); err != nil {
			log.Fatalf("Failed to execute remote script template: %v", err)
		}

		remoteScriptPath := fmt.Sprintf("/tmp/setup_remote_%s.sh", instanceName)
		err = sshutil.CopyContentToRemote(sshClient, scriptBuf.Bytes(), remoteScriptPath, "0755")
		if err != nil {
			log.Fatalf("Failed to copy rendered script to '%s': %v", remoteScriptPath, err)
		}
		log.Info("Remote setup script copied.")

		// 6. Execute remote script
		log.Info("Executing remote setup script This may take a while.")
		remoteCommand := fmt.Sprintf("INSTANCE_ID=%s bash %s", instanceName, remoteScriptPath)
		err = sshutil.RunRemoteCommand(sshClient, remoteCommand)
		if err != nil {
			// Capture the error but maybe don't make it fatal immediately
			log.Errorf("Remote script execution failed: %v", err)
			// Consider exiting with an error code here if the script failure is critical
			os.Exit(1)
		}

		log.Info("--------------------------------------------------")
		log.Info("Remote setup script execution finished successfully.")
		log.Infof("You may need to reconnect ('lambda connect %s') to see all changes.", instanceName)
		log.Info("--------------------------------------------------")
	},
}
