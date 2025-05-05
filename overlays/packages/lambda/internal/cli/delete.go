package cli

import (
	"os"

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
