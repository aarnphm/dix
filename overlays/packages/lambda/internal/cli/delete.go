package cli

import (
	"fmt"

	api "github.com/aarnphm/dix/overlays/packages/lambda/internal/apiclient"
	log "github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
)

var DeleteCmd = &cobra.Command{
	Use:               "delete <instance_name>",
	Short:             "Terminate the specified instance",
	Args:              cobra.ExactArgs(1),
	Aliases:           []string{"terminate"},
	ValidArgsFunction: completeInstanceNames,
	RunE: func(cmd *cobra.Command, args []string) error {
		instanceName := args[0]

		// 1. Find Instance
		apiKey, _ := cmd.Root().PersistentFlags().GetString("api-key")
		client, err := api.NewAPIClient(apiKey)
		if err != nil {
			return fmt.Errorf("failed to create API client: %w", err)
		}
		log.Debugf("Looking for instance '%s' to delete", instanceName)
		var instancesResp api.InstancesResponse
		err = client.Request("GET", "/instances", nil, &instancesResp)
		if err != nil {
			return fmt.Errorf("error fetching instances: %w", err)
		}
		var targetInstance *api.Instance
		for i := range instancesResp.Data {
			if instancesResp.Data[i].Name == instanceName {
				targetInstance = &instancesResp.Data[i]
				break
			}
		}
		if targetInstance == nil {
			return fmt.Errorf("no instance found with name '%s'. Cannot delete", instanceName)
		}

		instanceID := targetInstance.ID
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
			log.Infof("Instance '%s' (ID: %s) termination initiated successfully.", instanceName, instanceID)
		} else {
			log.Errorf("Failed to confirm termination for instance '%s' (ID: %s)", instanceName, instanceID)
			log.Debugf("API Response Data: %+v", terminateResp.Data)
			return fmt.Errorf("failed to confirm termination for instance '%s' (ID: %s)", instanceName, instanceID)
		}
		return nil
	},
}
