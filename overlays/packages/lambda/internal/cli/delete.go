package cli

import (
	"encoding/json"
	"fmt"
	"strings"

	api "github.com/aarnphm/dix/overlays/packages/lambda/internal/apiclient"
	log "github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
)

var DeleteCmd = &cobra.Command{
	Use:               "delete <instance_name_or_id>",
	Short:             "Terminate an instance",
	Args:              cobra.ExactArgs(1),
	Aliases:           []string{"terminate"},
	ValidArgsFunction: completeInstanceNames,
	RunE: func(cmd *cobra.Command, args []string) error {
		instanceIdentifier := args[0]
		outputFormat, _ := cmd.Root().PersistentFlags().GetString("output")
		outputFormat = strings.ToLower(outputFormat)
		jsonOutput := outputFormat == "json"

		if outputFormat != "" && outputFormat != "json" && outputFormat != "table" {
			return fmt.Errorf("invalid output format: %s. Supported formats: 'json', 'table'", outputFormat)
		}

		// 1. Find Instance by ID or Name
		apiKey, _ := cmd.Root().PersistentFlags().GetString("api-key")
		client, err := api.NewAPIClient(apiKey)
		if err != nil {
			return fmt.Errorf("failed to create API client: %w", err)
		}
		log.Debugf("Looking for instance '%s' to delete", instanceIdentifier)
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
			return fmt.Errorf("no instance found with name or ID '%s'. Cannot delete", instanceIdentifier)
		}

		instanceID := targetInstance.ID
		instanceName := targetInstance.Name
		log.Debugf("Found instance '%s' (ID: %s, Status: %s). Proceeding with termination",
			instanceName, instanceID, targetInstance.Status)

		// 2. Send Terminate Request
		terminateReq := api.TerminateRequest{
			InstanceIDs: []string{instanceID},
		}
		var terminateResp api.TerminateResponse
		err = client.Request("POST", "/instance-operations/terminate", terminateReq, &terminateResp)
		if err != nil {
			return fmt.Errorf("error sending terminate request for instance '%s' (ID: %s): %w", instanceName, instanceID, err)
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
			if jsonOutput {
				resp := map[string]interface{}{
					"instance_id":   instanceID,
					"instance_name": instanceName,
					"action":        "terminate",
					"status":        "initiated",
				}
				jsonBytes, _ := json.Marshal(resp)
				fmt.Println(string(jsonBytes))
			} else {
				log.Infof("Instance '%s' (ID: %s) termination initiated successfully.", instanceName, instanceID)
			}
		} else {
			log.Errorf("Failed to confirm termination for instance '%s' (ID: %s)", instanceName, instanceID)
			log.Debugf("API Response Data: %+v", terminateResp.Data)
			return fmt.Errorf("failed to confirm termination for instance '%s' (ID: %s)", instanceName, instanceID)
		}
		return nil
	},
}
