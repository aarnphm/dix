package cli

import (
	"fmt"
	"os"
	"regexp"
	"strings"
	"time"

	api "github.com/aarnphm/dix/overlays/packages/lambda/internal/apiclient"
	"github.com/aarnphm/dix/overlays/packages/lambda/internal/configutil"
	log "github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
)

var CreateCmd = &cobra.Command{
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
