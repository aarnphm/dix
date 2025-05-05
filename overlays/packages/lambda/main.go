package main

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strconv"

	"github.com/aarnphm/dix/overlays/packages/lambda/internal/cli"
	"github.com/aarnphm/dix/overlays/packages/lambda/internal/configutil"
	log "github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
)

var (
	rootCmd = &cobra.Command{
		Use:   "lambda",
		Short: "A CLI tool for managing Lambda Cloud resources",
		Long:  `lambda is a command-line tool to interact with the Lambda Cloud API for creating, connecting, setting up, and deleting instances.`,
		PersistentPreRun: func(cmd *cobra.Command, args []string) {
			// Read API key from flag or environment variable
			if apiKey == "" {
				apiKey = configutil.GetEnvWithDefault("LAMBDA_API_KEY", "")
				log.Debugf("API key loaded from environment variable LAMBDA_API_KEY: %s", apiKey)
			} else {
				log.Debugf("API key loaded from --api-key: %s", apiKey)
			}
			if apiKey == "" {
				log.Warn("API key not provided via --api-key flag or LAMBDA_API_KEY environment variable.")
			}
		},
	}
	apiKey string
)

func init() {
	// Add persistent flags
	rootCmd.PersistentFlags().StringVar(&apiKey, "api-key", "", "Lambda Cloud API key (env: LAMBDA_API_KEY)")

	// Add commands
	rootCmd.AddCommand(cli.CreateCmd)
	rootCmd.AddCommand(cli.ConnectCmd)
	rootCmd.AddCommand(cli.SetupCmd)
	rootCmd.AddCommand(cli.DeleteCmd)
	rootCmd.AddCommand(cli.CompletionCmd)
}

func main() {
	formatter := &log.TextFormatter{
		FullTimestamp:   true,
		TimestampFormat: "2006-01-02T15:04:05",
	}

	// Read DEBUG environment variable
	debugLevel, err := strconv.Atoi(configutil.GetEnvWithDefault("DEBUG", "1"))
	if err != nil {
		log.Warnf("Invalid DEBUG level '%d'. Using default level 0 (WARN). Error: %v", debugLevel, err)
		debugLevel = 0
	}

	switch debugLevel {
	case 3:
		log.SetLevel(log.TraceLevel)
		log.SetReportCaller(true)
		formatter.CallerPrettyfier = func(f *runtime.Frame) (string, string) {
			filename := filepath.Base(f.File)
			return "", fmt.Sprintf("[%s:L%d]", filename, f.Line)
		}
	case 2:
		log.SetLevel(log.DebugLevel)
	case 1:
		log.SetLevel(log.InfoLevel)
	case 0:
		log.SetLevel(log.WarnLevel)
	default:
		log.Warnf("Unknown DEBUG level '%d'. Using default level 0 (WARN).", debugLevel)
		log.SetLevel(log.WarnLevel)
	}

	// Set the customized formatter
	log.SetFormatter(formatter)
	log.Debugf("Log level set to %s based on DEBUG=%d", log.GetLevel(), debugLevel)

	if err := rootCmd.Execute(); err != nil {
		log.Fatalf("Error executing command: %v", err)
		os.Exit(1)
	}
}
