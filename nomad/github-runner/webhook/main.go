package main

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"log/slog"
	"net/http"
	"slices"
	"strings"

	"github.com/caarlos0/env/v11"
	nomad "github.com/hashicorp/nomad/api"
)

type Config struct {
	GitHubSecret     string `env:"GITHUB_WEBHOOK_SECRET,notEmpty"`
	GitHubPAT        string `env:"GITHUB_PAT,notEmpty"`
	GitHubOrg        string `env:"GITHUB_ORG,notEmpty"`
	GitHubRepo       string `env:"GITHUB_REPO,notEmpty"`
	NomadJobTemplate string `env:"NOMAD_JOB_TEMPLATE,notEmpty"`
	Addr             string `env:"ADDR"`
}

type GitHubRegistrationTokenResponse struct {
	Token     string `json:"token"`
	ExpiresAt string `json:"expires_at"`
}

type WebhookPayload struct {
	Action      string `json:"action"`
	WorkflowJob struct {
		Labels []string `json:"labels"`
	} `json:"workflow_job"`
}

func verifySignature(secret, signature string, payload []byte) bool {
	if !strings.HasPrefix(signature, "sha256=") {
		return false
	}

	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(payload)
	expectedMAC := hex.EncodeToString(mac.Sum(nil))
	receivedMAC := strings.TrimPrefix(signature, "sha256=")

	return hmac.Equal([]byte(expectedMAC), []byte(receivedMAC))
}

func fetchRegistrationToken(config Config) (string, error) {
	url := fmt.Sprintf("https://api.github.com/repos/%s/%s/actions/runners/registration-token",
		config.GitHubOrg, config.GitHubRepo)

	req, err := http.NewRequest("POST", url, nil)
	if err != nil {
		return "", fmt.Errorf("creating request: %w", err)
	}

	req.Header.Set("Authorization", "token "+config.GitHubPAT)
	req.Header.Set("Accept", "application/vnd.github+json")

	slog.Info("Requesting token from GitHub", "url", url)

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return "", fmt.Errorf("making request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("reading response: %w", err)
	}

	if resp.StatusCode != http.StatusCreated {
		return "", fmt.Errorf("GitHub API returned %d: %s", resp.StatusCode, string(body))
	}

	var tokenResp GitHubRegistrationTokenResponse
	if err := json.Unmarshal(body, &tokenResp); err != nil {
		return "", fmt.Errorf("parsing response: %w", err)
	}

	return tokenResp.Token, nil
}

func triggerRunnerJob(config Config, token string) error {
	client, err := nomad.NewClient(nomad.DefaultConfig())
	if err != nil {
		return fmt.Errorf("creating Nomad client: %w", err)
	}

	githubURL := fmt.Sprintf("https://github.com/%s/%s", config.GitHubOrg, config.GitHubRepo)

	meta := map[string]string{
		"github_url":    githubURL,
		"runner_token":  token,
		"runner_labels": "nomad",
	}

	slog.Info("Dispatching Nomad job", "job", config.NomadJobTemplate, "meta", meta)

	jobs := client.Jobs()
	resp, _, err := jobs.Dispatch(config.NomadJobTemplate, meta, nil, "", nil)
	if err != nil {
		return fmt.Errorf("dispatching job: %w", err)
	}

	slog.Info("Nomad job dispatched successfully", "dispatchedJobID", resp.DispatchedJobID, "evalID", resp.EvalID)

	return nil
}

type WebhookServer struct {
	config Config
}

func (s *WebhookServer) handleWebhook(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Bad request", http.StatusBadRequest)
		return
	}

	signature := r.Header.Get("X-Hub-Signature-256")
	if signature == "" {
		http.Error(w, "Forbidden", http.StatusForbidden)
		return
	}

	if !verifySignature(s.config.GitHubSecret, signature, body) {
		http.Error(w, "Forbidden", http.StatusForbidden)
		return
	}

	event := r.Header.Get("X-GitHub-Event")
	if event != "workflow_job" {
		slog.Debug("Ignoring event", "event", event)
		w.WriteHeader(http.StatusOK)
		return
	}

	var payload WebhookPayload
	if err := json.Unmarshal(body, &payload); err != nil {
		slog.Error("Error parsing payload", "error", err)
		http.Error(w, "Bad request", http.StatusBadRequest)
		return
	}

	labels := make([]string, len(payload.WorkflowJob.Labels))
	for i, label := range payload.WorkflowJob.Labels {
		labels[i] = strings.ToLower(label)
	}

	if payload.Action == "queued" && slices.Contains(labels, "nomad") {
		token, err := fetchRegistrationToken(s.config)
		if err != nil {
			slog.Error("Error fetching registration token", "error", err)
			http.Error(w, "Internal server error", http.StatusInternalServerError)
			return
		}

		if err := triggerRunnerJob(s.config, token); err != nil {
			slog.Error("Error launching runner job", "error", err)
			http.Error(w, "Internal server error", http.StatusInternalServerError)
			return
		}

		slog.Info("Runner job dispatched successfully")
		w.WriteHeader(http.StatusAccepted)
		return
	}

	w.WriteHeader(http.StatusOK)
}

func (s *WebhookServer) handleHealth(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status": "ok"}`))
}

func main() {
	cfg := Config{Addr: ":8080"}

	err := env.Parse(&cfg)
	if err != nil {
		log.Fatal(err)
	}

	server := &WebhookServer{config: cfg}

	http.HandleFunc("/", server.handleWebhook)
	http.HandleFunc("/health", server.handleHealth)

	slog.Info("Webhook server listening on", "addr", cfg.Addr)
	if err := http.ListenAndServe(cfg.Addr, nil); err != nil {
		log.Fatal(err)
	}
}
