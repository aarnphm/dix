package main

import (
	"bytes"
	_ "embed"
	"encoding/json"
	"errors"
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
	"golang.org/x/crypto/ssh/knownhosts"
	"golang.org/x/term"
)

const (
	apiURL            = "https://cloud.lambda.ai/api/v1"
	defaultRegion     = "us-south-3"
	sshKeyName        = "aaron-mbp16"
	remoteUser        = "ubuntu"
	remotePassword    = "toor"
	defaultSSHKeyPath = "~/.ssh/id_ed25519-paperspace"
	bitwardenNoteName = "pat-lambda"
)

//go:embed setup_remote.sh.in
var remoteSetupScriptTemplate string

type remoteSetupParams struct {
	RemoteUser     string
	RemotePassword string
	GhToken        string
}

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
		if _, ok := err.(*ssh.PassphraseMissingError); ok {
			log.Infof("SSH key %s seems to be encrypted.", expandedPath)
			fmt.Printf("Enter passphrase for key %s: ", expandedPath)
			bytePassword, err := term.ReadPassword(int(syscall.Stdin))
			if err != nil {
				return nil, fmt.Errorf("reading passphrase: %w", err)
			}
			fmt.Println()
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
		fmt.Fprintf(stdin, "C%s %d %s", perms, len(content), filename)
		stdin.Write([]byte(content))
		fmt.Fprint(stdin, "\x00") // Terminate with null byte
	}()

	log.Infof("Copying local file '%s' to remote '%s'", expandedLocalPath, remotePath)
	err = session.Run(fmt.Sprintf("scp -qt %s", directory))
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
		fmt.Fprintf(stdin, "C%s %d %s", perms, len(content), filename)
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

	log.Debugf("API Request: %s %s", method, url)
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

// Added for delete command
type TerminateRequest struct {
	InstanceIDs []string `json:"instance_ids"`
}

type TerminateResponse struct {
	Data struct {
		TerminatedInstanceIDs []string `json:"terminated_instance_ids"`
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

		log.Infof("Requesting instance type: %s, Name: %s", requestedInstanceTypeName, instanceName)

		// 2. Check for existing instance with the same name
		log.Infof("Checking for existing instance named '%s'", instanceName)
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
			if availableRegionMap[defaultRegion] {
				targetRegion = defaultRegion
				log.Infof("Using default region: %s (available for %s)", targetRegion, requestedInstanceTypeName)
			} else {
				// Find first available US region
				for _, r := range availableRegions {
					if strings.HasPrefix(r.Name, "us-") {
						targetRegion = r.Name
						log.Infof("Default region '%s' not available for '%s'. Using first available US region: %s", defaultRegion, requestedInstanceTypeName, targetRegion)
						break
					}
				}
				if targetRegion == "" { // Still not found
					log.Errorf("Requested instance type '%s' is not available in the default region ('%s') or any US region.", requestedInstanceTypeName, defaultRegion)
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
		var filesystemsResp FileSystemsResponse
		foundFS := false
		err = client.request("GET", "/file-systems", nil, &filesystemsResp)
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
				log.Warnf("Filesystem creation response name mismatch (expected %s, got %s), proceeding", filesystemName, createFsResp.Data.Name)
			}
			log.Infof("Filesystem '%s' created successfully.", filesystemName)
		}

		// 6. Launch Instance
		log.Infof("Launching instance '%s' (%s) in region '%s' with filesystem '%s'",
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
		log.Infof("Instance launch initiated with ID: %s. Waiting for it to become active", instanceID)

		// 7. Poll for Active Status and IP
		const maxRetries = 40 // 40 * 30s = 20 minutes
		var finalInstance Instance
		for i := 0; i < maxRetries; i++ {
			time.Sleep(30 * time.Second)
			var currentInstances InstancesResponse
			err = client.request("GET", "/instances", nil, &currentInstances)
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
		// Expand the default SSH key path for the informational message
		expandedKeyPath, _ := expandPath(defaultSSHKeyPath) // Ignore error for informational msg
		log.Infof("IMPORTANT: Connect manually once to add host key:")
		log.Infof("  ssh %s@%s -i %s", remoteUser, finalInstance.IP, expandedKeyPath)
		log.Infof("Then connect using:")
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

	client, err := newAPIClient()
	if err != nil {
		// Cannot log here during completion, return default
		return nil, cobra.ShellCompDirectiveError
	}

	var instancesResp InstancesResponse
	err = client.request("GET", "/instances", nil, &instancesResp)
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

// Function to establish an SSH connection
func establishSSHConnection(ipAddress, sshKeyPath, user string, useKnownHosts bool) (*ssh.Client, error) {
	// Get SSH key signer
	signer, err := getSSHKey(sshKeyPath)
	if err != nil {
		return nil, fmt.Errorf("failed to get SSH key: %w", err)
	}

	// Configure HostKeyCallback
	var hostKeyCallback ssh.HostKeyCallback
	if useKnownHosts {
		knownHostsPath, err := expandPath("~/.ssh/known_hosts")
		if err != nil {
			return nil, fmt.Errorf("failed to expand known_hosts path: %w", err)
		}
		callback, err := knownhosts.New(knownHostsPath)
		if err != nil {
			if os.IsNotExist(err) {
				log.Warnf("known_hosts file '%s' not found. Allowing first connection.", knownHostsPath)
				// Allow first connection if known_hosts doesn't exist
				// Or implement a prompt? For now, insecure.
				hostKeyCallback = ssh.InsecureIgnoreHostKey()
			} else {
				return nil, fmt.Errorf("failed to read known_hosts file '%s': %w", knownHostsPath, err)
			}
		} else {
			hostKeyCallback = callback
		}
	} else {
		log.Warn("Host key checking is disabled (InsecureIgnoreHostKey).")
		hostKeyCallback = ssh.InsecureIgnoreHostKey()
	}

	// Configure SSH client
	sshConfig := &ssh.ClientConfig{
		User: user,
		Auth: []ssh.AuthMethod{
			ssh.PublicKeys(signer),
		},
		HostKeyCallback: hostKeyCallback,
		Timeout:         30 * time.Second, // Increased timeout for initial connection/setup
	}
	log.Debugf("Attempting SSH auth with user: %s, Key Type: %s", sshConfig.User, signer.PublicKey().Type())

	// Dial the SSH server
	serverAddr := ipAddress + ":22"
	log.Debugf("Dialing SSH server %s with user %s", serverAddr, user)
	sshClient, err := ssh.Dial("tcp", serverAddr, sshConfig)
	if err != nil {
		// Specific error handling for knownhosts missing key
		var keyErr *knownhosts.KeyError
		if useKnownHosts && errors.As(err, &keyErr) && len(keyErr.Want) > 0 {
			knownHostsPath, _ := expandPath("~/.ssh/known_hosts") // Ignore error as we checked earlier
			log.Errorf("SSH host key verification failed for %s.", ipAddress)
			log.Errorf("The host key is not present in '%s'.", knownHostsPath)
			log.Infof("Please connect manually using 'ssh %s@%s' once to add the host key, then try again.", user, ipAddress)
			// Return a distinct error or handle appropriately
			return nil, fmt.Errorf("host key verification failed: %w", err)
		}
		return nil, fmt.Errorf("failed to dial SSH server: %w", err)
	}
	return sshClient, nil
}

var connectCmd = &cobra.Command{
	Use:               "connect <instance_name>",
	Short:             "Connect via SSH to the specified active instance",
	Args:              cobra.ExactArgs(1),
	ValidArgsFunction: completeInstanceNames,
	Run: func(cmd *cobra.Command, args []string) {
		instanceName := args[0]

		client, err := newAPIClient()
		if err != nil {
			log.Fatalf("Error initializing API client: %v", err)
		}

		log.Infof("Looking for instance '%s'", instanceName)
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
		log.Infof("Connecting to instance '%s' (%s)", instanceName, ipAddress)

		// Establish SSH connection using the helper function (with known_hosts check)
		sshClient, err := establishSSHConnection(ipAddress, defaultSSHKeyPath, remoteUser, true) // Use known_hosts
		if err != nil {
			log.Fatalf("Failed to establish SSH connection: %v", err)
			// Specific error handling for host key verification failure is now inside establishSSHConnection
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
		log.Debug("SSH session finished.")
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
		client, err := newAPIClient()
		if err != nil {
			log.Fatalf("Error initializing API client: %v", err)
		}
		log.Infof("Looking for instance '%s'", instanceName)
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
		log.Infof("Preparing setup for instance '%s' (%s)", instanceName, ipAddress)

		// 2. Get GitHub Token from Bitwarden
		log.Info("Retrieving GitHub token from Bitwarden")
		bwCmd := exec.Command("bw", "get", "notes", bitwardenNoteName)
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
			log.Fatalf("Failed to retrieve GitHub token (item note '%s') from Bitwarden. Is the note populated?", bitwardenNoteName)
		}
		log.Info("GitHub token retrieved successfully.")

		// 3. Establish SSH Connection (without strict known_hosts check for setup)
		log.Infof("Establishing SSH connection to %s@%s", remoteUser, ipAddress)
		// For setup, we might tolerate missing known_hosts entry initially, so set useKnownHosts=false
		sshClient, err := establishSSHConnection(ipAddress, defaultSSHKeyPath, remoteUser, false)
		if err != nil {
			log.Fatalf("Failed to establish SSH connection: %v", err)
		}
		defer sshClient.Close()
		log.Info("SSH connection established.")

		// 4. Copy necessary files
		filesToCopy := map[string]string{
			getEnvWithDefault("BW_PASS_FILE", "~/bw.pass"):                               "~/bw.pass",
			getEnvWithDefault("SSH_ID_FILE", "~/.ssh/id_ed25519-github"):                 "~/.ssh/id_ed25519-github",
			getEnvWithDefault("YATAI_CONFIG_FILE", "~/.local/share/bentoml/.yatai.yaml"): "~/.yatai.yaml",                // Original script copied from BENTOML_HOME/.yatai.yaml
			getEnvWithDefault("GPG_PRIVATE_KEY_FILE", "~/gpg-private-lambdalabs.key"):    "~/gpg-private-lambdalabs.key", // Added GPG key copy
		}
		for local, remote := range filesToCopy {
			expandedLocal, err := expandPath(local) // Expand local path before copying
			if err != nil {
				log.Warnf("Could not expand local path '%s', skipping copy: %v", local, err)
				continue
			}
			if _, err := os.Stat(expandedLocal); os.IsNotExist(err) {
				log.Warnf("Local file '%s' (expanded: '%s') does not exist, skipping copy.", local, expandedLocal)
				continue
			}

			err = copyFileToRemote(sshClient, expandedLocal, remote)
			if err != nil {
				log.Fatalf("Failed to copy file '%s' to '%s': %v", expandedLocal, remote, err)
			}
		}

		// 5. Render and copy setup script
		log.Info("Rendering remote setup script")
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
		log.Info("Executing remote setup script This may take a while.")
		remoteCommand := fmt.Sprintf("INSTANCE_ID=%s bash %s", instanceName, remoteScriptPath)
		err = runRemoteCommand(sshClient, remoteCommand)
		if err != nil {
			// Capture the error but maybe don't make it fatal immediately
			log.Errorf("Remote script execution failed: %v", err)
			// Consider exiting with an error code here if the script failure is critical
			os.Exit(1)
		}

		log.Info("--------------------------------------------------")
		log.Info("Remote setup script execution finished successfully.") // Changed message on success
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
		client, err := newAPIClient()
		if err != nil {
			log.Fatalf("Error initializing API client: %v", err)
		}
		log.Infof("Looking for instance '%s' to delete", instanceName)
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
			log.Fatalf("Error: No instance found with name '%s'. Cannot delete.", instanceName)
		}

		instanceID := targetInstance.ID
		log.Warnf("Found instance '%s' (ID: %s, Status: %s). Proceeding with termination",
			instanceName, instanceID, targetInstance.Status)

		// 2. Send Terminate Request
		terminateReq := TerminateRequest{
			InstanceIDs: []string{instanceID},
		}
		var terminateResp TerminateResponse
		err = client.request("POST", "/instance-operations/terminate", terminateReq, &terminateResp)
		if err != nil {
			log.Fatalf("Error sending terminate request for instance '%s' (ID: %s): %v", instanceName, instanceID, err)
		}

		// 3. Verify Response
		terminated := false
		for _, terminatedID := range terminateResp.Data.TerminatedInstanceIDs {
			if terminatedID == instanceID {
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
	Args:                  cobra.ExactValidArgs(1),
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
	// Add commands to root
	rootCmd.AddCommand(createCmd)
	rootCmd.AddCommand(connectCmd)
	rootCmd.AddCommand(setupCmd)
	rootCmd.AddCommand(deleteCmd)
	rootCmd.AddCommand(completionCmd)

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
	// Set log level based on environment variable
	logLevel := getEnvWithDefault("LOG_LEVEL", "info")
	switch strings.ToLower(logLevel) {
	case "debug":
		log.SetLevel(log.DebugLevel)
	case "warn", "warning":
		log.SetLevel(log.WarnLevel)
	case "error":
		log.SetLevel(log.ErrorLevel)
	case "verbose":
		log.SetLevel(log.TraceLevel)
	default:
		log.SetLevel(log.InfoLevel)
	}

	if err := rootCmd.Execute(); err != nil {
		// Cobra already prints the error, just exit
		os.Exit(1)
	}
}
