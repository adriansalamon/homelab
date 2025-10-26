package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"os"
	"slices"
	"strings"
	"time"
)

// https://reports.kea.isc.org/dev_guide/db/ddb/classisc_1_1dhcp__ddns_1_1NameChangeRequest.html
type NameChangeRequest struct {
	ChangeType             int    `json:"change-type"` // 0 for add/update, 1 for delete
	ForwardChange          bool   `json:"forward-change"`
	ReverseChange          bool   `json:"reverse-change"`
	Fqdn                   string `json:"fqdn"`
	IPAddress              string `json:"ip-address"`
	Dhcid                  string `json:"dhcid"`
	Expires                string `json:"lease-expires-on"`
	LeaseLength            int    `json:"lease-length"` // in seconds
	ConflictResolutionMode string `json:"conflict-resolution-mode"`
}

type Options struct {
	ConsulURL       string
	ConsulToken     string
	SiteName        string
	CleanupInterval time.Duration
}

var options Options

func main() {
	addr := net.UDPAddr{
		Port: 53010,
		IP:   net.ParseIP("127.0.0.1"),
	}

	consulUrl, ok := os.LookupEnv("CONSUL_URL")
	if !ok {
		slog.Error("Environment variable not set", "var", "CONSUL_URL")
		os.Exit(1)
	}

	consulTokenFile, ok := os.LookupEnv("CONSUL_TOKEN_FILE")
	if !ok {
		slog.Error("Environment variable not set", "var", "CONSUL_TOKEN_FILE")
		os.Exit(1)
	}

	token, err := os.ReadFile(consulTokenFile)
	if err != nil {
		slog.Error("Failed to read token file", "path", consulTokenFile, "error", err)
		os.Exit(1)
	}

	siteName, ok := os.LookupEnv("SITE_NAME")
	if !ok {
		slog.Error("Environment variable not set", "var", "SITE_NAME")
		os.Exit(1)
	}

	// Default cleanup interval to 1 hour if not specified
	cleanupIntervalStr, ok := os.LookupEnv("CLEANUP_INTERVAL")
	cleanupInterval := time.Hour
	if ok {
		parsed, err := time.ParseDuration(cleanupIntervalStr)
		if err != nil {
			slog.Error("Invalid duration format", "var", "CLEANUP_INTERVAL", "value", cleanupIntervalStr, "error", err)
			os.Exit(1)
		}
		cleanupInterval = parsed
	}

	options = Options{
		ConsulURL:       consulUrl,
		ConsulToken:     string(token),
		SiteName:        siteName,
		CleanupInterval: cleanupInterval,
	}

	conn, err := net.ListenUDP("udp", &addr)
	if err != nil {
		slog.Error("Failed to listen on UDP port", "port", addr.Port, "error", err)
		os.Exit(1)
	}
	defer conn.Close()

	slog.Info("Listening for Kea DDNS messages", "address", addr.String())
	slog.Info("Configuration loaded", "site", options.SiteName, "cleanup_interval", options.CleanupInterval)

	// Start the cleanup goroutine
	go startCleanupRoutine()

	buf := make([]byte, 8192)

	for {
		n, remoteAddr, err := conn.ReadFromUDP(buf)
		if err != nil {
			slog.Error("Failed to read UDP message", "remote", remoteAddr.String(), "error", err)
			continue
		}

		// First two bytes are the message length
		var ncr NameChangeRequest
		if err := json.Unmarshal(buf[2:n], &ncr); err != nil {
			slog.Error("Failed to unmarshal JSON", "remote", remoteAddr.String(), "error", err)
			continue
		}

		if ncr.ChangeType == 0 {
			err = ncr.registerConsul()
			if err != nil {
				slog.Error("Failed to register service", "dhcid", ncr.Dhcid, "hostname", ncr.Fqdn, "error", err)
			} else {
				slog.Info("Service registered", "dhcid", ncr.Dhcid, "hostname", ncr.Fqdn, "ip", ncr.IPAddress)
			}
		} else if ncr.ChangeType == 1 {
			err = ncr.deregisterFromConsul()
			if err != nil {
				slog.Error("Failed to deregister service", "dhcid", ncr.Dhcid, "error", err)
			} else {
				slog.Info("Service deregistered", "dhcid", ncr.Dhcid)
			}
		}
	}
}

func (ncr *NameChangeRequest) registerConsul() error {
	if ncr.ChangeType != 0 {
		return nil // Only register add/update
	}

	hostname, _ := strings.CutSuffix(ncr.Fqdn, ".")

	payload := map[string]any{
		"ID":      ncr.Dhcid,
		"Name":    hostname,
		"Address": ncr.IPAddress,
		"Tags":    []string{"kea-ddns", options.SiteName},
		"Meta": map[string]string{
			"lease-expires-on":         ncr.Expires,
			"conflict-resolution-mode": ncr.ConflictResolutionMode,
			"site":                     options.SiteName,
		},
	}

	data, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("failed to marshal Consul payload: %w", err)
	}

	req, err := http.NewRequest("PUT", fmt.Sprintf("%s/v1/agent/service/register", options.ConsulURL), bytes.NewBuffer(data))
	if err != nil {
		return fmt.Errorf("failed to create register request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Consul-Token", options.ConsulToken)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("error registering service: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("non-OK response from Consul: %s", resp.Status)
	}

	return nil
}

func (ncr *NameChangeRequest) deregisterFromConsul() error {
	return deregisterFromConsul(ncr.Dhcid)
}

func deregisterFromConsul(id string) error {
	req, err := http.NewRequest("PUT", fmt.Sprintf("%s/v1/agent/service/deregister/%s", options.ConsulURL, id), nil)
	if err != nil {
		return fmt.Errorf("failed to create deregister request: %w", err)
	}
	req.Header.Set("X-Consul-Token", options.ConsulToken)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("error deregistering service: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("non-OK response from Consul during deregistration: %s", resp.Status)
	}

	return nil
}

func startCleanupRoutine() {
	if err := cleanupExpiredServices(); err != nil {
		slog.Error("Cleanup failed", "error", err)
	}

	ticker := time.NewTicker(options.CleanupInterval)
	defer ticker.Stop()

	slog.Info("Cleanup routine started", "interval", options.CleanupInterval)

	for range ticker.C {
		if err := cleanupExpiredServices(); err != nil {
			slog.Error("Cleanup failed", "error", err)
		}
	}
}

type ConsulService struct {
	ID   string            `json:"ID"`
	Tags []string          `json:"Tags"`
	Meta map[string]string `json:"Meta"`
	Name string            `json:"Service"`
}

func cleanupExpiredServices() error {
	// Query Consul for all services with kea-ddns tag
	req, err := http.NewRequest("GET", fmt.Sprintf("%s/v1/agent/services", options.ConsulURL), nil)
	if err != nil {
		return fmt.Errorf("failed to create services query request: %w", err)
	}
	req.Header.Set("X-Consul-Token", options.ConsulToken)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("error querying Consul services: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("non-OK response from Consul during services query: %s", resp.Status)
	}

	var services map[string]ConsulService
	if err := json.NewDecoder(resp.Body).Decode(&services); err != nil {
		return fmt.Errorf("failed to decode Consul services response: %w", err)
	}

	now := time.Now().UTC()
	expiredCount := 0

	slog.Debug("Starting cleanup", "total_services", len(services), "site", options.SiteName)

	for _, service := range services {
		// Skip services not tagged with kea-ddns
		if !slices.Contains(service.Tags, "kea-ddns") {
			continue
		}

		expiresStr, ok := service.Meta["lease-expires-on"]
		if !ok {
			continue
		}

		// Parse the expiration time (format: YYYYMMDDHHmmss)
		expiresTime, err := time.Parse("20060102150405", expiresStr)
		if err != nil {
			slog.Error("Failed to parse lease expiration", "service_id", service.ID, "expires_str", expiresStr, "error", err)
			continue
		}

		// Add some buffer to the expiration time, we just want to remove stale services
		bufferTime := expiresTime.Add(time.Minute * 30)

		if now.After(bufferTime) {
			if err := deregisterFromConsul(service.ID); err != nil {
				slog.Error("Failed to deregister expired service", "service_id", service.ID, "error", err)
			} else {
				slog.Debug("Deregistered expired service", "service_id", service.ID, "expires_at", expiresTime)
				expiredCount++
			}
		}
	}

	if expiredCount > 0 {
		slog.Info("Cleanup completed", "removed", expiredCount, "site", options.SiteName)
	} else {
		slog.Debug("Cleanup completed", "removed", 0, "site", options.SiteName)
	}

	return nil
}
