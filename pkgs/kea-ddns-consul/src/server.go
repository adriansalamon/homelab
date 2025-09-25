package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"strings"
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
	ConsulURL   string
	ConsulToken string
}

var options Options

func main() {
	addr := net.UDPAddr{
		Port: 53010,
		IP:   net.ParseIP("127.0.0.1"),
	}

	consulUrl, ok := os.LookupEnv("CONSUL_URL")
	if !ok {
		log.Fatal("CONSUL_IP environment variable not set")
		os.Exit(1)
	}

	consulTokenFile, ok := os.LookupEnv("CONSUL_TOKEN_FILE")
	if !ok {
		log.Fatal("CONSUL_TOKEN_FILE environment variable not set")
		os.Exit(1)
	}

	token, err := os.ReadFile(consulTokenFile)
	if err != nil {
		log.Fatalf("Failed to read Consul token file: %v", err)
	}

	options = Options{
		ConsulURL:   consulUrl,
		ConsulToken: string(token),
	}

	conn, err := net.ListenUDP("udp", &addr)
	if err != nil {
		log.Fatalf("Failed to listen on UDP port %d: %v", addr.Port, err)
	}
	defer conn.Close()

	log.Printf("Listening for Kea DDNS messages on %s", addr.String())

	buf := make([]byte, 8192)

	for {
		n, remoteAddr, err := conn.ReadFromUDP(buf)
		if err != nil {
			log.Printf("Error reading JSON message: %v", err)
			continue
		}

		// First two bytes are the message length
		var ncr NameChangeRequest
		if err := json.Unmarshal(buf[2:n], &ncr); err != nil {
			log.Printf("Invalid JSON from %s: %s, %s", remoteAddr, string(buf[2:]), err)
			continue
		}

		if ncr.ChangeType == 0 {
			err = ncr.registerConsul()
			if err != nil {
				log.Printf("Failed to register service in Consul: %v", err)
			}
		} else if ncr.ChangeType == 1 {
			err = ncr.deregisterFromConsul()
			if err != nil {
				log.Printf("Failed to deregister service in Consul: %v", err)
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
		"Tags":    []string{"kea-ddns"},
		"Meta": map[string]string{
			"lease-expires-on":         ncr.Expires,
			"conflict-resolution-mode": ncr.ConflictResolutionMode,
		},
	}

	data, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("failed to marshal Consul payload: %w", err)
	}

	req, err := http.NewRequest("PUT", fmt.Sprintf("%s/v1/agent/service/register", options.ConsulURL), bytes.NewBuffer(data))
	if err != nil {
		return fmt.Errorf("failed to create deregister request: %w", err)
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
	req, err := http.NewRequest("PUT", fmt.Sprintf("%s/v1/agent/service/deregister/%s", options.ConsulURL, ncr.Dhcid), nil)
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
