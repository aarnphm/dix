package cli

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"text/tabwriter"

	api "github.com/aarnphm/dix/overlays/packages/lambda/internal/apiclient"
	"github.com/spf13/cobra"
)

var ListCmd = &cobra.Command{
	Use:   "list",
	Short: "List running Lambda Cloud instances",
	Args:  cobra.NoArgs,
	RunE: func(cmd *cobra.Command, args []string) error {
		apiKey, _ := cmd.Root().PersistentFlags().GetString("api-key")
		client, err := api.NewAPIClient(apiKey)
		if err != nil {
			return fmt.Errorf("error initializing API client: %w", err)
		}

		var instancesResp api.InstancesResponse
		err = client.Request("GET", "/instances", nil, &instancesResp)
		if err != nil {
			return fmt.Errorf("error fetching instances: %w", err)
		}

		outputFormat, _ := cmd.Root().PersistentFlags().GetString("output")

		switch outputFormat {
		case "json":
			jsonData, err := json.MarshalIndent(instancesResp.Data, "", "  ")
			if err != nil {
				return fmt.Errorf("failed to marshal instances to JSON: %w", err)
			}
			fmt.Println(string(jsonData))
		case "table", "":
			// Initialize tabwriter for aligned columns
			w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
			fmt.Fprintln(w, "NAME\tID\tIP_ADDRESS\tGPU_TYPE\tREGION\tSTATUS\tPRICE/HR\tUPTIME")

			if len(instancesResp.Data) == 0 {
                w.Flush()
				return nil
			}

			activeCount := 0
			for _, inst := range instancesResp.Data {
				// Skip non-active instances for the default list
				if inst.Status != "active" {
					continue
				}
				activeCount++

				// Extract GPU type like A100, H100_SXM5 from gpu_1x_A100 or gpu_8x_H100_SXM5
				gpuType := "N/A"
				parts := strings.SplitN(inst.InstanceType.Name, "gpu_", 2)
				if len(parts) == 2 {
					gpuType = parts[1]
				} else if inst.InstanceType.Name != "" {
					gpuType = inst.InstanceType.Name
				}

				uptimeStr := "-" // Launch time not available via API

				ipAddr := inst.IP
				if ipAddr == "" || ipAddr == "null" {
					ipAddr = "-"
				}

				regionName := inst.Region.Name

				fmt.Fprintf(w, "%s\t%s\t%s\t%s\t%s\t%s\t$%.2f\t%s\n",
					inst.Name,
					inst.ID,
					ipAddr,
					gpuType,
					regionName,
					inst.Status,
					float64(inst.InstanceType.PriceCentsPerHour)/100,
					uptimeStr,
				)
			}

			if activeCount != 0 {
				w.Flush()
			}
		default:
			return fmt.Errorf("invalid output format: %s. Supported formats: 'table', 'json'", outputFormat)
		}

		return nil
	},
}
