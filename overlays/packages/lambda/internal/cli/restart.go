package cli

import (
	"fmt"

	api "github.com/aarnphm/dix/overlays/packages/lambda/internal/apiclient"
	log "github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
)

var RestartCmd = &cobra.Command{
	Use:               "restart <instance_name>",
	Short:             "Restart the specified instance",
	Args:              cobra.ExactArgs(1),
	ValidArgsFunction: completeInstanceNames,
	RunE: func(cmd *cobra.Command, args []string) error {
		instanceName := args[0]

		// 1. Find Instance
		apiKey, _ := cmd.Root().PersistentFlags().GetString("api-key")
		client, err := api.NewAPIClient(apiKey)
		if err != nil {
			return fmt.Errorf("failed to create API client: %w", err)
		}
		log.Debugf("Looking for instance '%s' to restart", instanceName)
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
			return fmt.Errorf("no instance found with name '%s'. Cannot restart", instanceName)
		}

		instanceID := targetInstance.ID
		log.Debugf("Found instance '%s' (ID: %s, Status: %s). Proceeding with restart",
			instanceName, instanceID, targetInstance.Status)

		// 2. Send Restart Request
		restartReq := api.RestartRequest{
			InstanceIDs: []string{instanceID},
		}
		var restartResp api.RestartResponse
		err = client.Request("POST", "/instance-operations/restart", restartReq, &restartResp)
		if err != nil {
			return fmt.Errorf("error sending restart request for instance '%s' (ID: %s): %w", instanceName, instanceID, err)
		}

		// 3. Verify Response
		restarted := false
		for _, restartedInstance := range restartResp.Data.RestartedInstances {
			if restartedInstance.ID == instanceID {
				restarted = true
				break
			}
		}

		if restarted {
			log.Infof("Instance '%s' (ID: %s) restart initiated successfully.", instanceName, instanceID)
		} else {
			log.Errorf("Failed to confirm restart for instance '%s' (ID: %s)", instanceName, instanceID)
			log.Debugf("API Response Data: %+v", restartResp.Data)
			return fmt.Errorf("failed to confirm restart for instance '%s' (ID: %s)", instanceName, instanceID)
		}
		return nil
	},
}
