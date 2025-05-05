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
		// Cannot log here during completion, return default
		return nil, cobra.ShellCompDirectiveError
	}

	var instancesResp api.InstancesResponse
	err = client.Request("GET", "/instances", nil, &instancesResp)
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

// Function to fetch GPU types for completion
func completeGpuSpec(cmd *cobra.Command, args []string, toComplete string) ([]string, cobra.ShellCompDirective) {
	// Only complete the first argument
	if len(args) != 0 {
		return nil, cobra.ShellCompDirectiveNoFileComp
	}

	// Regex to match the start: number followed by 'x'
	re := regexp.MustCompile(`^([1-9][0-9]*)x(.*)$`)
	matches := re.FindStringSubmatch(toComplete)

	var numGPUs string
	var gpuPrefix string
	if len(matches) == 3 {
		numGPUs = matches[1]
		gpuPrefix = matches[2] // The part after 'x' user might have started typing
	} else {
		// If it doesn't match <num>x, don't suggest anything specific yet,
		// maybe user is typing number or just 'x'.
		// Let Cobra handle default file completion or whatever it does.
		// Or return specific guidance? For now, no suggestions.
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

	var suggestions []string
	expectedInstancePrefix := fmt.Sprintf("gpu_%sx_", numGPUs)

	for name := range typesResp.Data {
		if strings.HasPrefix(name, expectedInstancePrefix) {
			gpuType := strings.TrimPrefix(name, expectedInstancePrefix)
			// Only suggest if the type matches what the user has started typing after 'x'
			if strings.HasPrefix(gpuType, gpuPrefix) {
				// Format the suggestion back to the full <num>x<type> format
				suggestions = append(suggestions, fmt.Sprintf("%sx%s", numGPUs, gpuType))
			}
		}
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
