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
	RemoteUser          string
	RemotePassword      string
	RemoteGpgPassphrase string
	GhToken             string
	DixSetup            bool
	ForceSetup          bool
}

var (
	dixFlag   bool
	forceFlag bool
)

var SetupCmd = &cobra.Command{
	Use:               "setup <instance_name>",
	Short:             "Run the setup process on the specified active instance",
	Args:              cobra.ExactArgs(1),
	ValidArgsFunction: completeInstanceNames,
	RunE: func(cmd *cobra.Command, args []string) error {
		// Check if Bitwarden session exists
		if os.Getenv("BW_SESSION") == "" {
			return fmt.Errorf("bitwarden vault is locked. Please unlock it first (e.g., run 'bw unlock')")
		}

		instanceNameOrID := args[0]

		// 1. Find Instance
		apiKey, _ := cmd.Root().PersistentFlags().GetString("api-key")
		sshKeyPath, _ := cmd.Root().PersistentFlags().GetString("ssh-key-path")
		sshKeyName, _ := cmd.Root().PersistentFlags().GetString("ssh-key-name")
		client, err := api.NewAPIClient(apiKey)
		if err != nil {
			return fmt.Errorf("error initializing API client: %w", err)
		}

		log.Infof("Looking for instance '%s'", instanceNameOrID)
		var instancesResp api.InstancesResponse
		err = client.Request("GET", "/instances", nil, &instancesResp)
		if err != nil {
			return fmt.Errorf("error fetching instances: %w", err)
		}
		var targetInstance *api.Instance
		for i := range instancesResp.Data {
			if instancesResp.Data[i].Name == instanceNameOrID || instancesResp.Data[i].ID == instanceNameOrID {
				targetInstance = &instancesResp.Data[i]
				break
			}
		}
		if targetInstance == nil {
			return fmt.Errorf("no instance found with name or ID '%s'", instanceNameOrID)
		}
		if targetInstance.Status != "active" {
			return fmt.Errorf("instance '%s' found, but it is not active (status: '%s'). Cannot setup", targetInstance.Name, targetInstance.Status)
		}
		if targetInstance.IP == "" || targetInstance.IP == "null" {
			return fmt.Errorf("instance '%s' is active but does not have an IP address. Cannot setup yet", targetInstance.Name)
		}
		ipAddress := targetInstance.IP
		log.Infof("Found instance: %s (%s), IP: %s, Status: %s", targetInstance.Name, targetInstance.ID, ipAddress, targetInstance.Status)

		// Determine effective dix setup setting
		effectiveDixSetup := dixFlag

		log.Info("Retrieving GitHub token from Bitwarden")
		bwCmd := exec.Command("bw", "get", "notes", configutil.BitwardenNoteName)
		ghTokenBytes, err := bwCmd.Output()
		if err != nil {
			log.Error("Failed to execute 'bw get notes'. Is Bitwarden CLI installed, logged in, and unlocked?")
			stderr := ""
			if exitErr, ok := err.(*exec.ExitError); ok {
				stderr = string(exitErr.Stderr)
				log.Errorf("Bitwarden CLI stderr: %s", stderr)
			}
			return fmt.Errorf("error running bitwarden command: %w. Stderr: %s", err, stderr)
		}
		ghToken := strings.TrimSpace(string(ghTokenBytes))
		if ghToken == "" {
			return fmt.Errorf("failed to retrieve GitHub token (item note '%s') from Bitwarden. Is the note populated?", configutil.BitwardenNoteName)
		}
		log.Info("GitHub token retrieved successfully.")
		log.Info("Retrieving GPG passphrase from Bitwarden")
		gpgCmd := exec.Command("bw", "get", "notes", "gpg-github-paperspace-a4000-keys")
		gpgPassphraseBytes, err := gpgCmd.Output()
		if err != nil {
			log.Error("Failed to execute 'bw get notes' for GPG passphrase. Is Bitwarden CLI installed, logged in, and unlocked?")
			stderr := ""
			if exitErr, ok := err.(*exec.ExitError); ok {
				stderr = string(exitErr.Stderr)
				log.Errorf("Bitwarden CLI stderr: %s", stderr)
			}
			return fmt.Errorf("error running bitwarden command for GPG passphrase: %w. Stderr: %s", err, stderr)
		}
		remoteGpgPassphrase := strings.TrimSpace(string(gpgPassphraseBytes))
		if remoteGpgPassphrase == "" {
			return fmt.Errorf("failed to retrieve GPG passphrase (item note 'gpg-github-paperspace-a4000-keys') from Bitwarden. Is the note populated?")
		}
		log.Info("GPG passphrase retrieved successfully.")

		// 3. Establish SSH Connection (without strict known_hosts check for setup)
		log.Debugf("Attempting to establish SSH connection to %s using key %s", ipAddress, sshKeyPath)
		sshClient, err := sshutil.EstablishSSHConnection(ipAddress, sshKeyPath, configutil.RemoteUser, sshKeyName, true)
		if err != nil {
			return fmt.Errorf("failed to establish SSH connection to %s: %w", ipAddress, err)
		}
		defer sshClient.Close()
		log.Info("SSH connection established.")

		// 4. Copy necessary files, only for dix setup.
		if effectiveDixSetup {
			filesToCopy := map[string]string{
				configutil.GetEnvWithDefault("SSH_KNOWN_HOSTS_FILE", "~/.ssh/known_hosts"):              "~/.ssh/known_hosts",
				configutil.GetEnvWithDefault("SSH_ID_FILE", "~/.ssh/id_ed25519-github"):                 "~/.ssh/id_ed25519-github",
				configutil.GetEnvWithDefault("BW_PASS_FILE", "~/bw.pass"):                               "~/bw.pass",
				configutil.GetEnvWithDefault("IPYTHON_DIRECTORY", "~/.ipython"):                         "~/.ipython",
				configutil.GetEnvWithDefault("ATUIN_PASS_FILE", "~/atuin.key"):                          "~/atuin.key",
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
					return fmt.Errorf("failed to copy file '%s' to '%s': %w", expandedLocal, remote, err)
				}
			}
		}

		// 5. Render and copy setup script
		log.Info("Rendering remote setup script")
		params := remoteSetupParams{
			RemoteUser:          configutil.RemoteUser,
			RemotePassword:      configutil.RemotePassword,
			RemoteGpgPassphrase: remoteGpgPassphrase,
			GhToken:             ghToken,
			DixSetup:            effectiveDixSetup,
			ForceSetup:          forceFlag,
		}
		tmpl, err := template.New("remoteScript").Parse(remoteSetupScriptTemplate)
		if err != nil {
			return fmt.Errorf("failed to parse remote script template: %w", err)
		}
		var scriptBuf bytes.Buffer
		if err := tmpl.Execute(&scriptBuf, params); err != nil {
			return fmt.Errorf("failed to execute remote script template: %w", err)
		}

		remoteScriptPath := fmt.Sprintf("/tmp/setup_remote_%s.sh", targetInstance.Name)
		err = sshutil.CopyContentToRemote(sshClient, scriptBuf.Bytes(), remoteScriptPath, "0755")
		if err != nil {
			return fmt.Errorf("failed to copy rendered script to '%s': %w", remoteScriptPath, err)
		}
		log.Debug("Remote setup script copied.")

		// 6. Execute remote script
		log.Info("Executing remote setup script This may take a while.")
		remoteCommand := fmt.Sprintf("INSTANCE_ID=%s bash %s", targetInstance.Name, remoteScriptPath)
		err = sshutil.RunRemoteCommand(sshClient, remoteCommand)
		if err != nil {
			return fmt.Errorf("remote script execution failed: %w", err)
		}
		err = sshutil.RunRemoteCommand(sshClient, "rm "+remoteScriptPath)
		if err != nil {
			return fmt.Errorf("failed to remove remote script: %w", err)
		}

		log.Info("--------------------------------------------------")
		log.Info("Remote setup script execution finished successfully.")
		log.Infof("Next step: 'lm connect %s'", targetInstance.Name)
		log.Info("--------------------------------------------------")
		return nil
	},
}

func init() {
	SetupCmd.Flags().BoolVar(&dixFlag, "dix", false, "Perform aarnphm/dix's specific setup steps")
	SetupCmd.Flags().BoolVarP(&forceFlag, "force", "f", false, "Force setup even if already completed once")
}
