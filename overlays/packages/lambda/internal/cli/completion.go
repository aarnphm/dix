package cli

import (
	"fmt"
	"os"
	"regexp"
	"strings"

	api "github.com/aarnphm/dix/overlays/packages/lambda/internal/apiclient"
	"github.com/spf13/cobra"
)

// Function to fetch instance names for completion
func completeInstanceNames(cmd *cobra.Command, args []string, toComplete string) ([]string, cobra.ShellCompDirective) {
	// Prevent completion if already an argument is provided
	if len(args) != 0 {
		return nil, cobra.ShellCompDirectiveNoFileComp
	}

	apiKey, _ := cmd.Root().PersistentFlags().GetString("api-key")
	client, err := api.NewAPIClient(apiKey)
	if err != nil {
		return nil, cobra.ShellCompDirectiveError
	}

	var instancesResp api.InstancesResponse
	err = client.Request("GET", "/instances", nil, &instancesResp)
	if err != nil {
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

// Function to fetch GPU types for completion
func completeGpuSpec(cmd *cobra.Command, args []string, toComplete string) ([]string, cobra.ShellCompDirective) {
	// Only complete the first argument
	if len(args) != 0 {
		return nil, cobra.ShellCompDirectiveNoFileComp
	}

	apiKey, _ := cmd.Root().PersistentFlags().GetString("api-key")
	client, err := api.NewAPIClient(apiKey)
	if err != nil {
		return nil, cobra.ShellCompDirectiveError
	}

	var typesResp api.InstanceTypesResponse
	err = client.Request("GET", "/instance-types", nil, &typesResp)
	if err != nil {
		return nil, cobra.ShellCompDirectiveError
	}

	// Regex to match the full spec: <number>x<type>
	specRe := regexp.MustCompile(`^([1-9][0-9]*)x([a-zA-Z0-9_]+)$`)
	// Regex to extract spec from API type name: gpu_<number>x_<type>
	apiNameRe := regexp.MustCompile(`^gpu_([1-9][0-9]*)x_([a-zA-Z0-9_]+)$`)

	var suggestions []string

	if toComplete == "" {
		// If nothing is typed, suggest all possible specs
		for name := range typesResp.Data {
			matches := apiNameRe.FindStringSubmatch(name)
			if len(matches) == 3 {
				numGPUs := matches[1]
				gpuType := matches[2]
				suggestions = append(suggestions, fmt.Sprintf("%sx%s", numGPUs, gpuType))
			}
		}
	} else {
		// If user started typing, try to match and filter
		specMatches := specRe.FindStringSubmatch(toComplete)
		if len(specMatches) == 3 {
			// User typed something like "1xA10"
			numGPUs := specMatches[1]
			gpuPrefix := specMatches[2]
			expectedInstancePrefix := fmt.Sprintf("gpu_%sx_%s", numGPUs, gpuPrefix)

			for name := range typesResp.Data {
				if strings.HasPrefix(name, expectedInstancePrefix) {
					// Extract the full GPU type from the API name
					apiMatches := apiNameRe.FindStringSubmatch(name)
					if len(apiMatches) == 3 {
						// Format the suggestion back to the full <num>x<type> format
						suggestions = append(suggestions, fmt.Sprintf("%sx%s", apiMatches[1], apiMatches[2]))
					}
				}
			}
		} else if numPartMatch := regexp.MustCompile(`^([1-9][0-9]*)$`).FindStringSubmatch(toComplete); len(numPartMatch) == 2 {
			// User typed only a number like "1" or "8"
			numGPUs := numPartMatch[1]
			expectedInstancePrefix := fmt.Sprintf("gpu_%sx_", numGPUs)
			for name := range typesResp.Data {
				if strings.HasPrefix(name, expectedInstancePrefix) {
					apiMatches := apiNameRe.FindStringSubmatch(name)
					if len(apiMatches) == 3 {
						suggestions = append(suggestions, fmt.Sprintf("%sx%s", apiMatches[1], apiMatches[2]))
					}
				}
			}
		} else if numXPartMatch := regexp.MustCompile(`^([1-9][0-9]*)x$`).FindStringSubmatch(toComplete); len(numXPartMatch) == 2 {
			// User typed a number followed by 'x', like "1x"
			numGPUs := numXPartMatch[1]
			expectedInstancePrefix := fmt.Sprintf("gpu_%sx_", numGPUs)
			for name := range typesResp.Data {
				if strings.HasPrefix(name, expectedInstancePrefix) {
					apiMatches := apiNameRe.FindStringSubmatch(name)
					if len(apiMatches) == 3 {
						suggestions = append(suggestions, fmt.Sprintf("%sx%s", apiMatches[1], apiMatches[2]))
					}
				}
			}
		}
		// If toComplete doesn't match any pattern we handle, suggestions will be empty,
		// leading to default shell completion.
	}

	return suggestions, cobra.ShellCompDirectiveNoFileComp
}

var CompletionCmd = &cobra.Command{
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
	RunE: func(cmd *cobra.Command, args []string) error {
		switch args[0] {
		case "bash":
			cmd.Root().GenBashCompletion(os.Stdout)
		case "zsh":
			cmd.Root().GenZshCompletion(os.Stdout)
		case "fish":
			cmd.Root().GenFishCompletion(os.Stdout, true)
		case "powershell":
			cmd.Root().GenPowerShellCompletionWithDesc(os.Stdout)
		default:
			return fmt.Errorf("invalid shell specified: %s", args[0])
		}
		return nil
	},
}
