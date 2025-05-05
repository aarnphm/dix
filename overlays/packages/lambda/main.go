package main

import (
	"bytes"
	_ "embed"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strconv"
	"strings"
	"text/template"
	"time"

	api "github.com/aarnphm/dix/overlays/packages/lambda/internal/apiclient"
	"github.com/aarnphm/dix/overlays/packages/lambda/internal/configutil"
	"github.com/aarnphm/dix/overlays/packages/lambda/internal/sshutil"
	log "github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
	"golang.org/x/crypto/ssh"
	"golang.org/x/term"
)

//go:embed setup_remote.sh.in
var remoteSetupScriptTemplate string

type remoteSetupParams struct {
	RemoteUser     string
	RemotePassword string
	GhToken        string
}

var rootCmd = &cobra.Command{
	Use:   "lambda",
	Short: "A CLI tool for managing Lambda Cloud resources",
	Long:  `lambda is a command-line tool to interact with the Lambda Cloud API for creating, connecting, setting up, and deleting instances.`,
}

var createCmd = &cobra.Command{
	Use:   "create <gpus>x<type> [region]",
	Short: "Create a new Lambda Cloud instance",
	Args:  cobra.RangeArgs(1, 2),
	Run: func(cmd *cobra.Command, args []string) {
		instanceSpec := args[0]
		userRegion := ""
		if len(args) == 2 {
			userRegion = args[1]
		}

		client, err := api.NewAPIClient()
		if err != nil {
			log.Fatalf("Error initializing API client: %v", err)
		}

		// 1. Parse instance spec
		re := regexp.MustCompile(`^([1-9][0-9]*)x([a-zA-Z0-9_]+)$`)
		matches := re.FindStringSubmatch(instanceSpec)
		if len(matches) != 3 {
			log.Fatalf("Invalid instance specification format. Use <number_gpus>x<gpu_type> (e.g., 1xA100, 2xH100_SXM5).")
		}
		numGPUs := matches[1]
		gpuType := matches[2]
		requestedInstanceTypeName := fmt.Sprintf("gpu_%sx_%s", numGPUs, gpuType)
		instanceName := fmt.Sprintf("aaron-%s_%s", numGPUs, gpuType)

		log.Infof("Requesting instance type: %s, Name: %s", requestedInstanceTypeName, instanceName)

		// 2. Check for existing instance with the same name
		log.Infof("Checking for existing instance named '%s'", instanceName)
		var instancesResp api.InstancesResponse
		err = client.Request("GET", "/instances", nil, &instancesResp)
		if err != nil {
			log.Fatalf("Error fetching instances: %v", err)
		}
		for _, inst := range instancesResp.Data {
			if inst.Name == instanceName {
				log.Warnf("Instance named '%s' already exists with status '%s'", instanceName, inst.Status)
				log.Warnf("You can connect using: lambda connect %s", instanceName)
				os.Exit(0)
			}
		}

		// 3. Find the requested instance type and available regions
		log.Debugf("Fetching details for instance type '%s'", requestedInstanceTypeName)
		var typesResp api.InstanceTypesResponse
		err = client.Request("GET", "/instance-types", nil, &typesResp)
		if err != nil {
			log.Fatalf("Error fetching instance types: %v", err)
		}

		instanceTypeDetails, ok := typesResp.Data[requestedInstanceTypeName]
		if !ok {
			log.Errorf("Instance type '%s' not found.", requestedInstanceTypeName)
			log.Infof("Available instance types:")
			for name, details := range typesResp.Data {
				var regionNames []string
				for _, r := range details.RegionsWithCapacity {
					regionNames = append(regionNames, r.Name)
				}
				log.Infof("  - %s: %d GPUs (%s), Available in: %s",
					name,
					details.InstanceType.Specs.Gpus,
					details.InstanceType.GpuDescription,
					strings.Join(regionNames, ", "))
			}
			os.Exit(1)
		}

		// 4. Determine target region
		targetRegion := ""
		availableRegions := instanceTypeDetails.RegionsWithCapacity
		availableRegionMap := make(map[string]bool)
		for _, r := range availableRegions {
			availableRegionMap[r.Name] = true
		}

		if userRegion != "" {
			if availableRegionMap[userRegion] {
				targetRegion = userRegion
				log.Infof("Using user-specified region: %s (available for %s)", targetRegion, requestedInstanceTypeName)
			} else {
				log.Errorf("Requested instance type '%s' is not available in the specified region '%s'.", requestedInstanceTypeName, userRegion)
				var availableNames []string
				for _, r := range availableRegions {
					availableNames = append(availableNames, r.Name)
				}
				log.Infof("Available regions: %s", strings.Join(availableNames, ", "))
				os.Exit(1)
			}
		} else {
			if availableRegionMap[configutil.DefaultRegion] {
				targetRegion = configutil.DefaultRegion
				log.Infof("Using default region: %s (available for %s)", targetRegion, requestedInstanceTypeName)
			} else {
				// Find first available US region
				for _, r := range availableRegions {
					if strings.HasPrefix(r.Name, "us-") {
						targetRegion = r.Name
						log.Infof("Default region '%s' not available for '%s'. Using first available US region: %s", configutil.DefaultRegion, requestedInstanceTypeName, targetRegion)
						break
					}
				}
				if targetRegion == "" { // Still not found
					log.Errorf("Requested instance type '%s' is not available in the default region ('%s') or any US region.", requestedInstanceTypeName, configutil.DefaultRegion)
					var availableNames []string
					for _, r := range availableRegions {
						availableNames = append(availableNames, r.Name)
					}
					log.Infof("Available regions: %s", strings.Join(availableNames, ", "))
					os.Exit(1)
				}
			}
		}

		// 5. Check/Create Filesystem
		filesystemName := fmt.Sprintf("aaron-%s", targetRegion)
		log.Infof("Checking for filesystem '%s' in region '%s'", filesystemName, targetRegion)
		var filesystemsResp api.FileSystemsResponse
		foundFS := false
		err = client.Request("GET", "/file-systems", nil, &filesystemsResp)
		if err != nil {
			log.Fatalf("Error fetching filesystems: %v", err)
		}
		for _, fs := range filesystemsResp.Data {
			if fs.Name == filesystemName && fs.Region.Name == targetRegion {
				log.Infof("Using existing filesystem: %s", filesystemName)
				foundFS = true
				break
			}
		}

		if !foundFS {
			log.Infof("Filesystem '%s' not found. Creating", filesystemName)
			createFsReq := api.CreateFilesystemRequest{
				RegionName: targetRegion,
				Name:       []string{filesystemName},
			}
			var createFsResp api.CreateFilesystemResponse
			err = client.Request("POST", "/file-systems", createFsReq, &createFsResp) // Endpoint was /filesystems in bash?
			if err != nil {
				log.Fatalf("Error creating filesystem '%s': %v", filesystemName, err)
			}
			// API seems inconsistent here, response gives 'name', not ID? Assuming name is sufficient.
			if createFsResp.Data.Name != filesystemName {
				log.Warnf("Filesystem creation response name mismatch (expected %s, got %s), proceeding", filesystemName, createFsResp.Data.Name)
			}
			log.Infof("Filesystem '%s' created successfully.", filesystemName)
		}

		// 6. Launch Instance
		log.Infof("Launching instance '%s' (%s) in region '%s' with filesystem '%s'",
			instanceName, requestedInstanceTypeName, targetRegion, filesystemName)
		launchReq := api.LaunchRequest{
			RegionName:       targetRegion,
			InstanceTypeName: requestedInstanceTypeName,
			SSHKeyNames:      []string{configutil.SSHKeyName},
			FileSystemNames:  []string{filesystemName},
			Name:             instanceName,
		}
		var launchResp api.LaunchResponse
		err = client.Request("POST", "/instance-operations/launch", launchReq, &launchResp)
		if err != nil {
			log.Fatalf("Error launching instance: %v", err)
		}

		if len(launchResp.Data.InstanceIDs) == 0 {
			log.Fatalf("Instance launch initiated, but no instance ID returned.")
		}
		instanceID := launchResp.Data.InstanceIDs[0]
		log.Infof("Instance launch initiated with ID: %s. Waiting for it to become active", instanceID)

		// 7. Poll for Active Status and IP
		const maxRetries = 40 // 40 * 30s = 20 minutes
		var finalInstance api.Instance
		for i := 0; i < maxRetries; i++ {
			time.Sleep(30 * time.Second)
			var currentInstances api.InstancesResponse
			err = client.Request("GET", "/instances", nil, &currentInstances)
			if err != nil {
				log.Warnf("Error fetching instances during poll: %v. Retrying", err)
				continue
			}

			found := false
			for _, inst := range currentInstances.Data {
				if inst.ID == instanceID {
					log.Infof("Polling instance %s: Status=%s, IP=%s (%d/%d)", instanceID, inst.Status, inst.IP, i+1, maxRetries)
					if inst.Status == "active" && inst.IP != "" && inst.IP != "null" {
						finalInstance = inst
						found = true
						break
					}
					// If status is failed, stop polling
					if inst.Status == "terminated" || inst.Status == "failed" { // Assuming these are terminal states
						log.Fatalf("Instance %s entered status '%s'. Aborting.", instanceID, inst.Status)
					}
					found = true
					break
				}
			}

			if finalInstance.ID != "" {
				break
			}

			if !found {
				log.Warnf("Instance %s not found in list yet. Retrying (%d/%d)", instanceID, i+1, maxRetries)
			}
		}

		if finalInstance.ID == "" {
			log.Fatalf("Instance %s did not become active or get an IP address after %d retries.", instanceID, maxRetries)
		}

		log.Println("--------------------------------------------------")
		log.Infof("Instance '%s' created successfully!", finalInstance.Name)
		log.Infof("  ID: %s", finalInstance.ID)
		log.Infof("  Type: %s", requestedInstanceTypeName)
		log.Infof("  Region: %s", finalInstance.Region.Name)
		log.Infof("  Status: %s", finalInstance.Status)
		log.Infof("  IP Address: %s", finalInstance.IP)
		log.Println("--------------------------------------------------")
		expandedKeyPath, _ := configutil.ExpandPath(configutil.DefaultSSHKeyPath)
		log.Infof("IMPORTANT: Connect manually once to add host key:")
		log.Infof("  ssh %s@%s -i %s", configutil.RemoteUser, finalInstance.IP, expandedKeyPath)
		log.Infof("To connect:")
		log.Infof("  lambda connect %s", finalInstance.Name)
		log.Infof("To setup:")
		log.Infof("  lambda setup %s", finalInstance.Name)
	},
}

// Function to fetch instance names for completion
func completeInstanceNames(cmd *cobra.Command, args []string, toComplete string) ([]string, cobra.ShellCompDirective) {
	// Prevent completion if already an argument is provided
	if len(args) != 0 {
		return nil, cobra.ShellCompDirectiveNoFileComp
	}

	client, err := api.NewAPIClient()
	if err != nil {
		// Cannot log here during completion, return default
		return nil, cobra.ShellCompDirectiveError
	}

	var instancesResp api.InstancesResponse
	err = client.Request("GET", "/instances", nil, &instancesResp)
	if err != nil {
		// Cannot log here during completion, return default
		return nil, cobra.ShellCompDirectiveError
	}

	var names []string
	for _, inst := range instancesResp.Data {
		// Simple prefix matching for completion
		if strings.HasPrefix(inst.Name, toComplete) {
			names = append(names, inst.Name)
		}
	}

	return names, cobra.ShellCompDirectiveNoFileComp
}

var connectCmd = &cobra.Command{
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
			log.Fatalf("Error: Instance '%s' found, but it is not active (status: '%s').", instanceName, targetInstance.Status)
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

var setupCmd = &cobra.Command{
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
			log.Fatalf("Error: Instance '%s' found, but it is not active (status: '%s'). Cannot setup.", instanceName, targetInstance.Status)
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

var deleteCmd = &cobra.Command{
	Use:               "delete <instance_name>",
	Short:             "Terminate the specified instance",
	Args:              cobra.ExactArgs(1),
	Aliases:           []string{"terminate"},
	ValidArgsFunction: completeInstanceNames,
	Run: func(cmd *cobra.Command, args []string) {
		instanceName := args[0]

		// 1. Find Instance
		client, err := api.NewAPIClient()
		if err != nil {
			log.Fatalf("Error initializing API client: %v", err)
		}
		log.Infof("Looking for instance '%s' to delete", instanceName)
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
			log.Fatalf("Error: No instance found with name '%s'. Cannot delete.", instanceName)
		}

		instanceID := targetInstance.ID
		log.Warnf("Found instance '%s' (ID: %s, Status: %s). Proceeding with termination",
			instanceName, instanceID, targetInstance.Status)

		// 2. Send Terminate Request
		terminateReq := api.TerminateRequest{
			InstanceIDs: []string{instanceID},
		}
		var terminateResp api.TerminateResponse
		err = client.Request("POST", "/instance-operations/terminate", terminateReq, &terminateResp)
		if err != nil {
			log.Fatalf("Error sending terminate request for instance '%s' (ID: %s): %v", instanceName, instanceID, err)
		}

		// 3. Verify Response
		terminated := false
		for _, terminatedInstance := range terminateResp.Data.TerminatedInstances {
			if terminatedInstance.ID == instanceID {
				terminated = true
				break
			}
		}

		if terminated {
			log.Infof("Instance '%s' (ID: %s) termination initiated successfully.", instanceName, instanceID)
		} else {
			log.Errorf("Failed to confirm termination for instance '%s' (ID: %s)", instanceName, instanceID)
			log.Debugf("API Response Data: %+v", terminateResp.Data)
			// Exit with error code even if API call succeeded but didn't confirm the ID
			os.Exit(1)
		}
	},
}

var completionCmd = &cobra.Command{
	Use:   "completion [bash|zsh|fish|powershell]",
	Short: "Generate completion script",
	Long: `To load completions:

Bash:

  $ source <(lambda completion bash)

  # To load completions for each session, execute once:
  # Linux:
  $ lambda completion bash > /etc/bash_completion.d/lambda
  # macOS:
  $ lambda completion bash > $(brew --prefix)/etc/bash_completion.d/lambda

Zsh:

  # If shell completion is not already enabled in your environment,
  # you will need to enable it.  You can execute the following once:

  $ echo "autoload -U compinit; compinit" >> ~/.zshrc

  # To load completions for each session, execute once:
  $ lambda completion zsh > "${fpath[1]}/_lambda"

  # You will need to start a new shell for this setup to take effect.

Fish:

  $ lambda completion fish | source

  # To load completions for each session, execute once:
  $ lambda completion fish > ~/.config/fish/completions/lambda.fish

PowerShell:

  PS> lambda completion powershell | Out-String | Invoke-Expression

  # To load completions for every new session, run:
  PS> lambda completion powershell > lambda.ps1
  # and source this file from your PowerShell profile.
`,
	DisableFlagsInUseLine: true,
	ValidArgs:             []string{"bash", "zsh", "fish", "powershell"},
	Args:                  cobra.MatchAll(cobra.ExactArgs(1), cobra.OnlyValidArgs),
	Run: func(cmd *cobra.Command, args []string) {
		switch args[0] {
		case "bash":
			cmd.Root().GenBashCompletion(os.Stdout)
		case "zsh":
			cmd.Root().GenZshCompletion(os.Stdout)
		case "fish":
			cmd.Root().GenFishCompletion(os.Stdout, true)
		case "powershell":
			cmd.Root().GenPowerShellCompletionWithDesc(os.Stdout)
		}
	},
}

func init() {
	rootCmd.AddCommand(createCmd)
	rootCmd.AddCommand(connectCmd)
	rootCmd.AddCommand(setupCmd)
	rootCmd.AddCommand(deleteCmd)
	rootCmd.AddCommand(completionCmd)

	// TODO: Add flags if necessary (e.g., --api-key, --ssh-key)
}

func main() {
	// Initialize custom formatter embedding TextFormatter
	formatter := &log.TextFormatter{
		FullTimestamp:   true,
		TimestampFormat: "2006-01-02T15:04:05",
	}

	// Read DEBUG environment variable
	debugLevel, err := strconv.Atoi(configutil.GetEnvWithDefault("DEBUG", "0"))
	if err != nil {
		log.Warnf("Invalid DEBUG level '%d'. Using default level 0 (WARN). Error: %v", debugLevel, err)
		debugLevel = 0
	}

	switch debugLevel {
	case 3:
		log.SetLevel(log.TraceLevel)
		log.SetReportCaller(true)
		formatter.CallerPrettyfier = func(f *runtime.Frame) (string, string) {
			filename := filepath.Base(f.File)
			return "", fmt.Sprintf("[%s:L%d]", filename, f.Line)
		}
	case 2:
		log.SetLevel(log.DebugLevel)
		log.SetReportCaller(false)
		formatter.CallerPrettyfier = nil
	case 1:
		log.SetLevel(log.InfoLevel)
		log.SetReportCaller(false)
		formatter.CallerPrettyfier = nil
	case 0:
		log.SetLevel(log.WarnLevel)
		log.SetReportCaller(false)
		formatter.CallerPrettyfier = nil
	default:
		log.Warnf("Unknown DEBUG level '%d'. Using default level 0 (WARN).", debugLevel)
		log.SetLevel(log.WarnLevel)
		log.SetReportCaller(false)
		formatter.CallerPrettyfier = nil
	}

	// Set the customized formatter
	log.SetFormatter(formatter)
	log.Debugf("Log level set to %s based on DEBUG=%d", log.GetLevel(), debugLevel)

	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}
