package main

import (
	"bytes"
	_ "embed"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"regexp"
	"strings"
	"syscall"
	"text/template"
	"time"

	log "github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
	"golang.org/x/crypto/ssh"
	"golang.org/x/term"
)

const (
	apiURL            = "https://cloud.lambda.ai/api/v1"
	defaultRegion     = "us-south-3"
	sshKeyName        = "aaron-mbp16"
	remoteUser        = "ubuntu"
	remotePassword    = "toor"
	defaultSSHKeyPath = "~/.ssh/id_ed25519-github"
	bitwardenNoteName = "pat-lambda"
)

//go:embed setup_remote.sh.in
var remoteSetupScriptTemplate string

type remoteSetupParams struct {
	RemoteUser     string
	RemotePassword string
	GhToken        string
}

// --- SSH Helper Functions ---

func expandPath(path string) (string, error) {
	if strings.HasPrefix(path, "~/") {
		usr, err := user.Current()
		if err != nil {
			return "", fmt.Errorf("getting current user: %w", err)
		}
		return filepath.Join(usr.HomeDir, path[2:]), nil
	}
	return path, nil
}

func getSSHKey(keyPath string) (ssh.Signer, error) {
	expandedPath, err := expandPath(keyPath)
	if err != nil {
		return nil, fmt.Errorf("expanding SSH key path '%s': %w", keyPath, err)
	}
	keyBytes, err := os.ReadFile(expandedPath)
	if err != nil {
		return nil, fmt.Errorf("reading SSH key file '%s': %w", expandedPath, err)
	}
	signer, err := ssh.ParsePrivateKey(keyBytes)
	if err != nil {
		// Check if it needs a passphrase
		if _, ok := err.(*ssh.PassphraseMissingError); ok {
			fmt.Printf("Enter passphrase for key %s: ", expandedPath)
			bytePassword, err := term.ReadPassword(int(syscall.Stdin))
			if err != nil {
				return nil, fmt.Errorf("reading passphrase: %w", err)
			}
			fmt.Println()
			signer, err = ssh.ParsePrivateKeyWithPassphrase(keyBytes, bytePassword)
			if err != nil {
				return nil, fmt.Errorf("parsing private key with passphrase: %w", err)
			}
		} else {
			return nil, fmt.Errorf("parsing private key '%s': %w", expandedPath, err)
		}
	}
	return signer, nil
}

func runRemoteCommand(client *ssh.Client, command string) error {
	session, err := client.NewSession()
	if err != nil {
		return fmt.Errorf("failed to create SSH session: %w", err)
	}
	defer session.Close()

	session.Stdout = os.Stdout
	session.Stderr = os.Stderr

	log.Infof("Running remote command: %s", command)
	err = session.Run(command)
	if err != nil {
		return fmt.Errorf("failed to run remote command '%s': %w", command, err)
	}
	return nil
}

func copyFileToRemote(client *ssh.Client, localPath, remotePath string) error {
	expandedLocalPath, err := expandPath(localPath)
	if err != nil {
		return fmt.Errorf("expanding local path '%s': %w", localPath, err)
	}

	fileInfo, err := os.Stat(expandedLocalPath)
	if err != nil {
		if os.IsNotExist(err) {
			log.Warnf("Local file '%s' does not exist, skipping copy.", expandedLocalPath)
			return nil // Not a fatal error if the file doesn't exist
		}
		return fmt.Errorf("stat local file '%s': %w", expandedLocalPath, err)
	}

	fileBytes, err := os.ReadFile(expandedLocalPath)
	if err != nil {
		return fmt.Errorf("reading local file '%s': %w", expandedLocalPath, err)
	}

	content := string(fileBytes)
	perms := fmt.Sprintf("%04o", fileInfo.Mode().Perm())
	filename := filepath.Base(remotePath)
	directory := filepath.Dir(remotePath)

	session, err := client.NewSession()
	if err != nil {
		return fmt.Errorf("failed to create SSH session for file copy: %w", err)
	}
	defer session.Close()

	// Use scp protocol via stdin
	stdin, err := session.StdinPipe()
	if err != nil {
		return fmt.Errorf("failed to get stdin pipe: %w", err)
	}

	go func() {
		defer stdin.Close()
		fmt.Fprintf(stdin, "C%s %d %s\n", perms, len(content), filename)
		stdin.Write([]byte(content))
		fmt.Fprint(stdin, "\x00") // Terminate with null byte
	}()

	log.Infof("Copying local file '%s' to remote '%s'", expandedLocalPath, remotePath)
	err = session.Run(fmt.Sprintf("/usr/bin/scp -qt %s", directory))
	if err != nil {
		return fmt.Errorf("failed to run scp command for '%s': %w", remotePath, err)
	}
	return nil
}

func copyContentToRemote(client *ssh.Client, content []byte, remotePath string, perms string) error {
	filename := filepath.Base(remotePath)
	directory := filepath.Dir(remotePath)

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
		stdin.Write(content)
		fmt.Fprint(stdin, "\x00") // Terminate with null byte
	}()

	log.Infof("Copying content to remote '%s'", remotePath)
	err = session.Run(fmt.Sprintf("/usr/bin/scp -qt %s", directory))
	if err != nil {
		return fmt.Errorf("failed to run scp command for '%s': %w", remotePath, err)
	}
	return nil
}

type apiClient struct {
	apiKey string
	client *http.Client
}

func newAPIClient() (*apiClient, error) {
	apiKey := os.Getenv("LAMBDA_API_KEY")
	if apiKey == "" {
		return nil, fmt.Errorf("LAMBDA_API_KEY environment variable is not set")
	}
	return &apiClient{
		apiKey: apiKey,
		client: &http.Client{Timeout: 30 * time.Second},
	}, nil
}

func (c *apiClient) request(method, endpoint string, body interface{}, result interface{}) error {
	url := apiURL + endpoint
	var reqBody []byte
	var err error
	if body != nil {
		reqBody, err = json.Marshal(body)
		if err != nil {
			return fmt.Errorf("failed to marshal request body: %w", err)
		}
	}

	req, err := http.NewRequest(method, url, bytes.NewBuffer(reqBody))
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Authorization", "Bearer "+c.apiKey)
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}

	log.Debugf("API Request: %s %s\n", method, url)
	resp, err := c.client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to execute request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		// Try to read error body
		var errResp struct {
			Error struct {
				Message string `json:"message"`
			} `json:"error"`
		}
		bodyBytes, _ := io.ReadAll(resp.Body)
		_ = json.Unmarshal(bodyBytes, &errResp)
		errMsg := fmt.Sprintf("API request failed with status %d", resp.StatusCode)
		if errResp.Error.Message != "" {
			errMsg += ": " + errResp.Error.Message
		}
		return fmt.Errorf(errMsg)
	}

	if result != nil {
		if err := json.NewDecoder(resp.Body).Decode(result); err != nil {
			return fmt.Errorf("failed to decode response body: %w", err)
		}
	}

	return nil
}

type Instance struct {
	ID     string `json:"id"`
	Name   string `json:"name"`
	IP     string `json:"ip"`
	Status string `json:"status"`
	Region struct {
		Name string `json:"name"`
	} `json:"region"`
}

type InstancesResponse struct {
	Data []Instance `json:"data"`
}

type InstanceType struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	Specs       struct {
		Vcpus  int `json:"vcpus"`
		MemGiB int `json:"mem_gib"`
		Gpus   int `json:"gpus"`
	} `json:"specs"`
	GpuDescription string `json:"gpu_description"`
}

type Region struct {
	Name string `json:"name"`
}

type InstanceTypeDetails struct {
	InstanceType        InstanceType `json:"instance_type"`
	RegionsWithCapacity []Region     `json:"regions_with_capacity_available"`
}

type InstanceTypesResponse struct {
	Data map[string]InstanceTypeDetails `json:"data"`
}

type FileSystem struct {
	ID     string `json:"id"`
	Name   string `json:"name"`
	Region struct {
		Name string `json:"name"`
	} `json:"region"`
}

type FileSystemsResponse struct {
	Data []FileSystem `json:"data"`
}

type LaunchRequest struct {
	RegionName       string   `json:"region_name"`
	InstanceTypeName string   `json:"instance_type_name"`
	SSHKeyNames      []string `json:"ssh_key_names"`
	FileSystemNames  []string `json:"file_system_names,omitempty"`
	Name             string   `json:"name"`
	Quantity         int      `json:"quantity,omitempty"`
}

type LaunchResponse struct {
	Data struct {
		InstanceIDs []string `json:"instance_ids"`
	} `json:"data"`
}

type CreateFilesystemRequest struct {
	RegionName string   `json:"region_name"`
	Name       []string `json:"name"`
}

type CreateFilesystemResponse struct {
	Data struct {
		Name string `json:"name"`
	} `json:"data"`
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

		client, err := newAPIClient()
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

		log.Infof("Requesting instance type: %s, Name: %s\n", requestedInstanceTypeName, instanceName)

		// 2. Check for existing instance with the same name
		log.Infof("Checking for existing instance named '%s'\n", instanceName)
		var instancesResp InstancesResponse
		err = client.request("GET", "/instances", nil, &instancesResp)
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
		var typesResp InstanceTypesResponse
		err = client.request("GET", "/instance-types", nil, &typesResp)
		if err != nil {
			log.Fatalf("Error fetching instance types: %v", err)
		}

		instanceTypeDetails, ok := typesResp.Data[requestedInstanceTypeName]
		if !ok {
			log.Errorf("Instance type '%s' not found.\n", requestedInstanceTypeName)
			log.Infof("Available instance types:")
			for name, details := range typesResp.Data {
				var regionNames []string
				for _, r := range details.RegionsWithCapacity {
					regionNames = append(regionNames, r.Name)
				}
				log.Infof("  - %s: %d GPUs (%s), Available in: %s\n",
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
				log.Infof("Using user-specified region: %s (available for %s)\n", targetRegion, requestedInstanceTypeName)
			} else {
				log.Errorf("Requested instance type '%s' is not available in the specified region '%s'.\n", requestedInstanceTypeName, userRegion)
				var availableNames []string
				for _, r := range availableRegions {
					availableNames = append(availableNames, r.Name)
				}
				log.Infof("Available regions: %s\n", strings.Join(availableNames, ", "))
				os.Exit(1)
			}
		} else {
			if availableRegionMap[defaultRegion] {
				targetRegion = defaultRegion
				log.Infof("Using default region: %s (available for %s)\n", targetRegion, requestedInstanceTypeName)
			} else {
				// Find first available US region
				for _, r := range availableRegions {
					if strings.HasPrefix(r.Name, "us-") {
						targetRegion = r.Name
						log.Infof("Default region '%s' not available for '%s'. Using first available US region: %s\n", defaultRegion, requestedInstanceTypeName, targetRegion)
						break
					}
				}
				if targetRegion == "" { // Still not found
					log.Errorf("Requested instance type '%s' is not available in the default region ('%s') or any US region.\n", requestedInstanceTypeName, defaultRegion)
					var availableNames []string
					for _, r := range availableRegions {
						availableNames = append(availableNames, r.Name)
					}
					log.Infof("Available regions: %s\n", strings.Join(availableNames, ", "))
					os.Exit(1)
				}
			}
		}

		// 5. Check/Create Filesystem
		filesystemName := fmt.Sprintf("aaron-%s", targetRegion)
		log.Infof("Checking for filesystem '%s' in region '%s'...", filesystemName, targetRegion)
		var filesystemsResp FileSystemsResponse
		foundFS := false
		err = client.request("GET", "/file-systems", nil, &filesystemsResp)
		if err != nil {
			log.Fatalf("Error fetching filesystems: %v", err)
		}
		for _, fs := range filesystemsResp.Data {
			if fs.Name == filesystemName && fs.Region.Name == targetRegion {
				log.Infof("Using existing filesystem: %s\n", filesystemName)
				foundFS = true
				break
			}
		}

		if !foundFS {
			log.Infof("Filesystem '%s' not found. Creating...\n", filesystemName)
			createFsReq := CreateFilesystemRequest{
				RegionName: targetRegion,
				Name:       []string{filesystemName},
			}
			var createFsResp CreateFilesystemResponse
			err = client.request("POST", "/file-systems", createFsReq, &createFsResp) // Endpoint was /filesystems in bash?
			if err != nil {
				log.Fatalf("Error creating filesystem '%s': %v", filesystemName, err)
			}
			// API seems inconsistent here, response gives 'name', not ID? Assuming name is sufficient.
			if createFsResp.Data.Name != filesystemName {
				log.Warnf("Filesystem creation response name mismatch (expected %s, got %s), proceeding...", filesystemName, createFsResp.Data.Name)
			}
			log.Infof("Filesystem '%s' created successfully.\n", filesystemName)
		}

		// 6. Launch Instance
		log.Infof("Launching instance '%s' (%s) in region '%s' with filesystem '%s'...\n",
			instanceName, requestedInstanceTypeName, targetRegion, filesystemName)
		launchReq := LaunchRequest{
			RegionName:       targetRegion,
			InstanceTypeName: requestedInstanceTypeName,
			SSHKeyNames:      []string{sshKeyName},
			FileSystemNames:  []string{filesystemName},
			Name:             instanceName,
		}
		var launchResp LaunchResponse
		err = client.request("POST", "/instance-operations/launch", launchReq, &launchResp)
		if err != nil {
			log.Fatalf("Error launching instance: %v", err)
		}

		if len(launchResp.Data.InstanceIDs) == 0 {
			log.Fatalf("Instance launch initiated, but no instance ID returned.")
		}
		instanceID := launchResp.Data.InstanceIDs[0]
		log.Infof("Instance launch initiated with ID: %s. Waiting for it to become active...\n", instanceID)

		// 7. Poll for Active Status and IP
		const maxRetries = 40 // 40 * 30s = 20 minutes
		var finalInstance Instance
		for i := 0; i < maxRetries; i++ {
			time.Sleep(30 * time.Second)
			var currentInstances InstancesResponse
			err = client.request("GET", "/instances", nil, &currentInstances)
			if err != nil {
				log.Warnf("Error fetching instances during poll: %v. Retrying...", err)
				continue
			}

			found := false
			for _, inst := range currentInstances.Data {
				if inst.ID == instanceID {
					log.Infof("Polling instance %s: Status=%s, IP=%s (%d/%d)\n", instanceID, inst.Status, inst.IP, i+1, maxRetries)
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
				log.Warnf("Instance %s not found in list yet. Retrying... (%d/%d)", instanceID, i+1, maxRetries)
			}
		}

		if finalInstance.ID == "" {
			log.Fatalf("Instance %s did not become active or get an IP address after %d retries.", instanceID, maxRetries)
		}

		log.Println("--------------------------------------------------")
		log.Infof("Instance '%s' created successfully!\n", finalInstance.Name)
		log.Infof("  ID: %s\n", finalInstance.ID)
		log.Infof("  Type: %s\n", requestedInstanceTypeName)
		log.Infof("  Region: %s\n", finalInstance.Region.Name)
		log.Infof("  Status: %s\n", finalInstance.Status)
		log.Infof("  IP Address: %s\n", finalInstance.IP)
		log.Println("--------------------------------------------------")
		log.Infof("To connect: lambda connect %s\n", finalInstance.Name)
		log.Infof("To setup:   lambda setup %s\n", finalInstance.Name)
	},
}

var connectCmd = &cobra.Command{
	Use:   "connect <instance_name>",
	Short: "Connect via SSH to the specified active instance",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		instanceName := args[0]

		client, err := newAPIClient()
		if err != nil {
			log.Fatalf("Error initializing API client: %v", err)
		}

		log.Infof("Looking for instance '%s'...\n", instanceName)
		var instancesResp InstancesResponse
		err = client.request("GET", "/instances", nil, &instancesResp)
		if err != nil {
			log.Fatalf("Error fetching instances: %v", err)
		}

		var targetInstance *Instance
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
		log.Infof("Connecting to instance '%s' (%s)...\n", instanceName, ipAddress)

		// Expand ~ in ssh key path
		sshKeyPath := defaultSSHKeyPath
		if strings.HasPrefix(sshKeyPath, "~/") {
			usr, err := user.Current()
			if err != nil {
				log.Fatalf("Error getting current user for SSH key path expansion: %v", err)
			}
			sshKeyPath = filepath.Join(usr.HomeDir, sshKeyPath[2:])
		}

		sshArgs := []string{
			"-i", sshKeyPath,
			fmt.Sprintf("%s@%s", remoteUser, ipAddress),
		}

		log.Debugf("Executing SSH command: ssh %s", strings.Join(sshArgs, " "))

		sshCmd := exec.Command("ssh", sshArgs...)
		sshCmd.Stdin = os.Stdin
		sshCmd.Stdout = os.Stdout
		sshCmd.Stderr = os.Stderr

		if err := sshCmd.Run(); err != nil {
			if exitErr, ok := err.(*exec.ExitError); ok {
				// SSH likely exited with a non-zero code, which is common (e.g., user exits shell)
				// We don't necessarily need to treat this as a fatal error of the lambda tool itself.
				log.Debugf("SSH command finished with exit code: %d", exitErr.ExitCode())
				os.Exit(exitErr.ExitCode())
			} else {
				// Other error (e.g., ssh command not found)
				log.Fatalf("Error executing SSH command: %v", err)
			}
		}
	},
}

var setupCmd = &cobra.Command{
	Use:   "setup <instance_name>",
	Short: "Run the setup process on the specified active instance",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		instanceName := args[0]

		// 1. Find Instance
		client, err := newAPIClient()
		if err != nil {
			log.Fatalf("Error initializing API client: %v", err)
		}
		log.Infof("Looking for instance '%s'...\n", instanceName)
		var instancesResp InstancesResponse
		err = client.request("GET", "/instances", nil, &instancesResp)
		if err != nil {
			log.Fatalf("Error fetching instances: %v", err)
		}
		var targetInstance *Instance
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
		log.Infof("Preparing setup for instance '%s' (%s)...\n", instanceName, ipAddress)

		// 2. Get GitHub Token from Bitwarden
		log.Info("Retrieving GitHub token from Bitwarden...")
		bwCmd := exec.Command("bw", "get", "notes", bitwardenNoteName)
		ghTokenBytes, err := bwCmd.Output() // Use Output to capture stdout
		if err != nil {
			log.Error("Failed to execute 'bw get notes'. Is Bitwarden CLI installed, logged in, and unlocked?")
			if exitErr, ok := err.(*exec.ExitError); ok {
				log.Errorf("Bitwarden CLI stderr: %s", string(exitErr.Stderr))
			}
			log.Fatalf("Error running bitwarden command: %v", err)
		}
		ghToken := strings.TrimSpace(string(ghTokenBytes))
		if ghToken == "" {
			log.Fatalf("Failed to retrieve GitHub token (item note '%s') from Bitwarden. Is the note populated?", bitwardenNoteName)
		}
		log.Info("GitHub token retrieved successfully.")

		// 3. Prepare SSH connection
		sshKeyPath := defaultSSHKeyPath
		signer, err := getSSHKey(sshKeyPath)
		if err != nil {
			log.Fatalf("Failed to get SSH key: %v", err)
		}
		sshConfig := &ssh.ClientConfig{
			User: remoteUser,
			Auth: []ssh.AuthMethod{
				ssh.PublicKeys(signer),
			},
			HostKeyCallback: ssh.InsecureIgnoreHostKey(), // TODO: Use known_hosts checking for production
			Timeout:         10 * time.Second,
		}

		log.Infof("Establishing SSH connection to %s@%s...", remoteUser, ipAddress)
		sshClient, err := ssh.Dial("tcp", ipAddress+":22", sshConfig)
		if err != nil {
			log.Fatalf("Failed to dial SSH: %v", err)
		}
		defer sshClient.Close()
		log.Info("SSH connection established.")

		// 4. Copy necessary files
		filesToCopy := map[string]string{
			getEnvWithDefault("BW_PASS_FILE", "~/bw.pass"):                            "~/bw.pass",
			getEnvWithDefault("SSH_ID_FILE", "~/.ssh/id_ed25519-github"):              "~/.ssh/id_ed25519-github",
			getEnvWithDefault("YATAI_CONFIG_FILE", "~/.config/yatai/yatai.yaml"):      "~/.yatai.yaml",                // Original script copied from BENTOML_HOME/.yatai.yaml
			getEnvWithDefault("GPG_PRIVATE_KEY_FILE", "~/gpg-private-lambdalabs.key"): "~/gpg-private-lambdalabs.key", // Added GPG key copy
		}
		for local, remote := range filesToCopy {
			err = copyFileToRemote(sshClient, local, remote)
			if err != nil {
				log.Fatalf("Failed to copy file '%s' to '%s': %v", local, remote, err)
			}
		}

		// 5. Render and copy setup script
		log.Info("Rendering remote setup script...")
		params := remoteSetupParams{
			RemoteUser:     remoteUser,
			RemotePassword: remotePassword,
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
		err = copyContentToRemote(sshClient, scriptBuf.Bytes(), remoteScriptPath, "0755") // Make executable
		if err != nil {
			log.Fatalf("Failed to copy rendered script to '%s': %v", remoteScriptPath, err)
		}
		log.Info("Remote setup script copied.")

		// 6. Execute remote script
		log.Info("Executing remote setup script... This may take a while.")
		remoteCommand := fmt.Sprintf("INSTANCE_ID=%s bash %s", instanceName, remoteScriptPath)
		err = runRemoteCommand(sshClient, remoteCommand)
		if err != nil {
			log.Warnf("Remote script execution failed: %v", err)
			// Don't make this fatal, the script might have partially succeeded or failed internally
		}

		log.Info("--------------------------------------------------")
		log.Info("Remote setup script execution finished.")
		log.Info("You may need to reconnect ('lambda connect %s') to see all changes.", instanceName)
		log.Info("--------------------------------------------------")
	},
}

var deleteCmd = &cobra.Command{
	Use:   "delete <instance_name>",
	Short: "Terminate the specified instance",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("delete command called (not implemented yet)")
		// TODO: Implement delete logic
		// args[0] is the instance name
	},
}

func init() {
	// Add commands to root
	rootCmd.AddCommand(createCmd)
	rootCmd.AddCommand(connectCmd)
	rootCmd.AddCommand(setupCmd)
	rootCmd.AddCommand(deleteCmd)

	// TODO: Add flags if necessary (e.g., --api-key, --ssh-key)
}

func getEnvWithDefault(key, defaultValue string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return defaultValue
}

func main() {
	// Configure logrus
	log.SetFormatter(&log.TextFormatter{
		FullTimestamp: true,
	})
	log.SetOutput(os.Stdout)
	// Optionally set log level from env var or flag later
	// log.SetLevel(log.InfoLevel)

	if err := rootCmd.Execute(); err != nil {
		// Cobra already prints the error, just exit
		os.Exit(1)
	}
}
