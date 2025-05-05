package cli

import (
	"os"
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

	client, err := api.NewAPIClient()
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
