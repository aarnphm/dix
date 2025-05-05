package apiclient

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"

	log "github.com/sirupsen/logrus"
)

const (
	apiURL = "https://cloud.lambda.ai/api/v1"
)

// APIClient wraps the HTTP client and API key.
type APIClient struct {
	apiKey string
	client *http.Client
}

// NewAPIClient creates a new client for interacting with the Lambda Cloud API.
func NewAPIClient() (*APIClient, error) {
	apiKey := os.Getenv("LAMBDA_API_KEY")
	if apiKey == "" {
		return nil, fmt.Errorf("LAMBDA_API_KEY environment variable is not set")
	}
	return &APIClient{
		apiKey: apiKey,
		client: &http.Client{Timeout: 60 * time.Second}, // Increased timeout slightly
	}, nil
}

// Request makes a request to the Lambda Cloud API.
func (c *APIClient) Request(method, endpoint string, body any, result any) error {
	url := apiURL + endpoint
	var reqBody []byte
	var err error

	// Marshal request body if provided
	if body != nil {
		reqBody, err = json.Marshal(body)
		if err != nil {
			return fmt.Errorf("failed to marshal request body: %w", err)
		}
		log.Tracef("%s %s: %s", method, url, string(reqBody))
	}

	// Create HTTP request
	req, err := http.NewRequest(method, url, bytes.NewBuffer(reqBody))
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	// Set headers
	req.Header.Set("Authorization", "Bearer "+c.apiKey)
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	req.Header.Set("User-Agent", "dix-lambda-cli/0.1") // Add a user agent

	log.Debugf("%s %s", method, url)
	resp, err := c.client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to execute request to %s: %w", url, err)
	}
	defer resp.Body.Close()

	bodyBytes, readErr := io.ReadAll(resp.Body)
	if readErr != nil {
		log.Warnf("Failed to read response body from %s %s: %v", method, url, readErr)
		// Don't return yet, maybe we can still use status code or headers
	}
	log.Tracef("%s %s: %s", method, url, string(bodyBytes))

	// Check status code
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		// Try to parse standard Lambda error response
		var errResp struct {
			Error struct {
				Code    string `json:"code"`
				Message string `json:"message"`
			} `json:"error"`
		}
		errUnmarshal := json.Unmarshal(bodyBytes, &errResp)
		errMsg := ""
		if errUnmarshal == nil && errResp.Error.Message != "" {
			errMsg += fmt.Sprintf(": [%s] %s", errResp.Error.Code, errResp.Error.Message)
		} else if len(bodyBytes) > 0 {
			truncatedBody := string(bodyBytes)
			if len(truncatedBody) > 200 {
				truncatedBody = truncatedBody[:200] + "..."
			}
			errMsg += fmt.Sprintf(". Response body: %s", truncatedBody)
		}
		return fmt.Errorf("%s %s failed with status %s%s", method, url, resp.Status, errMsg)
	}

	// Decode successful response if result pointer is provided
	if result != nil {
		if len(bodyBytes) == 0 {
			// Handle cases like 204 No Content where body is expectedly empty
			if resp.StatusCode == http.StatusNoContent {
				log.Debugf("%s %s returned %s, no body to decode.", method, url, resp.Status)
				return nil
			}
			return fmt.Errorf("%s %s succeeded (%s) but response body was empty", method, url, resp.Status)
		}
		if err := json.Unmarshal(bodyBytes, result); err != nil {
			return fmt.Errorf("failed to decode successful response body from %s %s: %w", method, url, err)
		}
	}

	log.Debugf("%s %s (%s)", method, url, resp.Status)
	return nil
}
