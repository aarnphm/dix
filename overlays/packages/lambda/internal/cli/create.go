package cli

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	api "github.com/aarnphm/dix/overlays/packages/lambda/internal/apiclient"
	"github.com/aarnphm/dix/overlays/packages/lambda/internal/configutil"
	log "github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
)

var CreateCmd = &cobra.Command{
	Use:               "create <gpus>x<type> [region]",
	Short:             "Create a new Lambda Cloud instance",
	Args:              cobra.RangeArgs(1, 2),
	ValidArgsFunction: completeGpuSpec,
	RunE: func(cmd *cobra.Command, args []string) error {
		instanceSpec := args[0]
		userRegion := ""
		if len(args) == 2 {
			userRegion = args[1]
		}

		apiKey, _ := cmd.Root().PersistentFlags().GetString("api-key")
		prefix, _ := cmd.Flags().GetString("prefix")
		client, err := api.NewAPIClient(apiKey)
		if err != nil {
			return fmt.Errorf("error initializing API client: %w", err)
		}

		// 1. Parse instance spec
		re := regexp.MustCompile(`^([1-9][0-9]*)x([a-zA-Z0-9_]+)$`)
		matches := re.FindStringSubmatch(instanceSpec)
		if len(matches) != 3 {
			return fmt.Errorf("invalid instance specification format. Use <number_gpus>x<gpu_type> (e.g., 1xA100, 2xH100_SXM5)")
		}
		numGPUs := matches[1]
		gpuType := matches[2]
		requestedInstanceTypeName := fmt.Sprintf("gpu_%sx_%s", numGPUs, gpuType)
		// Generate random suffix
		suffixBytes := make([]byte, 4)
		_, err = rand.Read(suffixBytes)
		if err != nil {
			// Handle error appropriately, maybe return it or log fatal
			// For now, just log and continue, but this might not be ideal
			log.Warnf("Failed to generate random suffix: %v", err)
		}
		randomSuffix := hex.EncodeToString(suffixBytes)
		instanceName := fmt.Sprintf("%s-%s_%s-%s", prefix, numGPUs, gpuType, randomSuffix)

		log.Infof("Requesting instance type: %s, Name: %s", requestedInstanceTypeName, instanceName)

		maxInstancesPerType, _ := cmd.Flags().GetInt("max-instances-per-type")
		log.Debugf("Checking max instances limit (%d) for GPU type '%s'", maxInstancesPerType, gpuType)
		var instancesResp api.InstancesResponse
		err = client.Request("GET", "/instances", nil, &instancesResp)
		if err != nil {
			return fmt.Errorf("error fetching instances: %w", err)
		}
		existingSameTypeCount := 0
		var existingInstancesInfo []string
		for _, inst := range instancesResp.Data {
			// Only consider active instances
			if inst.Status != "active" {
				continue
			}
			// Extract GPU type from existing instance's type name (e.g., "gpu_1x_a100" -> "a100")
			parts := strings.SplitN(inst.InstanceType.Name, "x_", 2)
			if len(parts) == 2 {
				existingGpuType := parts[1]

				compareExistingType := existingGpuType
				compareRequestedType := gpuType

				parts = strings.SplitN(existingGpuType, "_", 2)
				if len(parts) > 0 {
					compareExistingType = parts[0]
				}

				parts = strings.SplitN(gpuType, "_", 2)
				if len(parts) > 0 {
					compareRequestedType = parts[0]
				}

				if compareExistingType == compareRequestedType {
					existingSameTypeCount++
					existingInstancesInfo = append(existingInstancesInfo,
						fmt.Sprintf("  - Name: %s, ID: %s, IP: %s, Region: %s",
							inst.Name, inst.ID, inst.IP, inst.Region.Name))
				}
			}
		}

		if existingSameTypeCount >= maxInstancesPerType {
			log.Warnf("Maximum number of active instances (%d) reached for GPU type '%s'.", maxInstancesPerType, gpuType)
			log.Warnf("Found %d existing active instance(s):", existingSameTypeCount)
			for _, info := range existingInstancesInfo {
				log.Warn(info)
			}
			log.Warnf("To connect, use: lambda connect <instance_name>")
			return nil
		}
		log.Debugf("Found %d active instances of type '%s'. Limit (%d) not reached.", existingSameTypeCount, gpuType, maxInstancesPerType)

		// 3. Find the requested instance type and available regions
		log.Debugf("Fetching details for instance type '%s'", requestedInstanceTypeName)
		var typesResp api.InstanceTypesResponse
		err = client.Request("GET", "/instance-types", nil, &typesResp)
		if err != nil {
			return fmt.Errorf("error fetching instance types: %w", err)
		}

		instanceTypeDetails, ok := typesResp.Data[requestedInstanceTypeName]
		if !ok {
			log.Warnf("Instance type '%s' not found. Available instance types:", requestedInstanceTypeName)
			for name, details := range typesResp.Data {
				var regionNames []string
				for _, r := range details.RegionsWithCapacity {
					regionNames = append(regionNames, r.Name)
				}
				if len(regionNames) != 0 {
					log.Warnf("  %s: %d GPUs (%s), Available in: %s",
						name,
						details.InstanceType.Specs.Gpus,
						details.InstanceType.GpuDescription,
						strings.Join(regionNames, ", "))
				}
			}
			return fmt.Errorf("instance type '%s' not found", requestedInstanceTypeName)
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
				log.Debugf("Using user-specified region: %s (available for %s)", targetRegion, requestedInstanceTypeName)
			} else {
				log.Errorf("Requested instance type '%s' is not available in the specified region '%s'.", requestedInstanceTypeName, userRegion)
				var availableNames []string
				for _, r := range availableRegions {
					availableNames = append(availableNames, r.Name)
				}
				if len(availableNames) > 0 {
					log.Debugf("Available regions: %s", strings.Join(availableNames, ", "))
				}
				return fmt.Errorf("instance type '%s' unavailable in region '%s'", requestedInstanceTypeName, userRegion)
			}
		} else {
			if availableRegionMap[configutil.DefaultRegion] {
				targetRegion = configutil.DefaultRegion
				log.Debugf("Using default region: %s (available for %s)", targetRegion, requestedInstanceTypeName)
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
					return fmt.Errorf("instance type '%s' unavailable in default/US regions", requestedInstanceTypeName)
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
			return fmt.Errorf("error fetching filesystems: %w", err)
		}
		for _, fs := range filesystemsResp.Data {
			if fs.Name == filesystemName && fs.Region.Name == targetRegion {
				log.Debugf("Using existing filesystem: %s", filesystemName)
				foundFS = true
				break
			}
		}

		if !foundFS {
			log.Infof("Filesystem '%s' not found. Creating", filesystemName)
			createFsReq := api.CreateFilesystemRequest{
				RegionName: targetRegion,
				Name:       filesystemName,
			}
			var createFsResp api.CreateFilesystemResponse
			err = client.Request("POST", "/filesystems", createFsReq, &createFsResp) // Endpoint was /filesystems in bash?
			if err != nil {
				return fmt.Errorf("error creating filesystem '%s': %w", filesystemName, err)
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
			return fmt.Errorf("error launching instance: %w", err)
		}

		if len(launchResp.Data.InstanceIDs) == 0 {
			return fmt.Errorf("instance launch initiated, but no instance ID returned")
		}
		instanceID := launchResp.Data.InstanceIDs[0]
		log.Debugf("Instance launch initiated with ID: %s. Waiting for it to become active", instanceID)

		// 7. Poll for Active Status and IP
		const maxRetries = 40 // 40 * 30s = 20 minutes
		var finalInstance api.Instance
		for attempt := range maxRetries {
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
					ipDisplay := inst.IP
					if ipDisplay == "" || ipDisplay == "null" {
						ipDisplay = "xxx.xx.xxx.xxx"
					}
					log.Infof("Polling instance %s: Status=%-7s, IP=%s (%02d/%d)", instanceID, inst.Status, ipDisplay, attempt+1, maxRetries)
					if inst.Status == "active" && inst.IP != "" && inst.IP != "null" {
						finalInstance = inst
						found = true
						break
					}
					// If status is failed, stop polling
					if inst.Status == "terminated" || inst.Status == "failed" { // Assuming these are terminal states
						return fmt.Errorf("instance %s entered status '%s'. Aborting", instanceID, inst.Status)
					}
					found = true
					break
				}
			}

			if finalInstance.ID != "" {
				break
			}

			if !found {
				log.Warnf("Instance %s not found in list yet. Retrying (%d/%d)", instanceID, attempt+1, maxRetries)
			}
		}

		if finalInstance.ID == "" {
			return fmt.Errorf("instance %s did not become active or get an IP address after %d retries", instanceID, maxRetries)
		}

		log.Println("--------------------------------------------------")
		log.Infof("Instance '%s' created successfully!", finalInstance.Name)
		log.Infof("  ID: %s", finalInstance.ID)
		log.Infof("  Type: %s", requestedInstanceTypeName)
		log.Infof("  Region: %s", finalInstance.Region.Name)
		log.Infof("  Status: %s", finalInstance.Status)
		log.Infof("  IP Address: %s", finalInstance.IP)
		log.Println("--------------------------------------------------")
		log.Infof("IMPORTANT: Connect manually once to add host key:")
		log.Infof("  ssh %s@%s", configutil.RemoteUser, finalInstance.IP)
		log.Infof("To connect:")
		log.Infof("  lambda connect %s", finalInstance.Name)
		log.Infof("To connect:")
		log.Infof("  lambda connect %s", finalInstance.Name)
		// Only show setup instructions if ~/bw.pass exists
		homeDir, _ := os.UserHomeDir()
		bwPassPath := filepath.Join(homeDir, "bw.pass")
		if _, err := os.Stat(bwPassPath); err == nil {
			log.Infof("To setup:")
			log.Infof("  lambda setup %s", finalInstance.Name)
		}
		return nil
	},
}

func init() {
	CreateCmd.Flags().String("prefix", "generic", "Prefix for the instance name")
	CreateCmd.Flags().Int("max-instances-per-type", 2, "Maximum number of active instances allowed for the same GPU type")
}
