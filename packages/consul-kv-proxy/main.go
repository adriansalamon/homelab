package main

import (
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"

	consulapi "github.com/hashicorp/consul/api"
)

func main() {
	port := getEnv("PORT", "8080")
	consulAddr := getEnv("CONSUL_ADDR", "http://127.0.0.1:8500")

	http.HandleFunc("/", handleRequest(consulAddr))
	http.HandleFunc("/health", handleHealth)

	log.Printf("Starting Consul KV proxy on port %s", port)
	log.Printf("Consul address: %s", consulAddr)

	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal(err)
	}
}

func handleRequest(consulAddr string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// Only allow POST/PUT
		if r.Method != http.MethodPost && r.Method != http.MethodPut {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		// Extract bearer token
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			http.Error(w, "Authorization header required", http.StatusUnauthorized)
			return
		}
		token := strings.TrimPrefix(authHeader, "Bearer ")

		// Extract key from URL path (remove leading slash)
		key := strings.TrimPrefix(r.URL.Path, "/")
		if key == "" {
			http.Error(w, "Key path required", http.StatusBadRequest)
			return
		}

		// Read value from body
		value, err := io.ReadAll(r.Body)
		if err != nil {
			http.Error(w, "Failed to read body", http.StatusBadRequest)
			return
		}

		config := consulapi.DefaultConfig()
		config.Address = consulAddr
		config.Token = token

		client, err := consulapi.NewClient(config)
		if err != nil {
			log.Printf("Failed to create Consul client: %v", err)
			http.Error(w, "Internal error", http.StatusInternalServerError)
			return
		}

		// Write to Consul KV
		kv := client.KV()
		_, err = kv.Put(&consulapi.KVPair{
			Key:   key,
			Value: value,
		}, nil)

		if err != nil {
			log.Printf("Failed to write to Consul: %v", err)
			http.Error(w, fmt.Sprintf("Failed to write: %v", err), http.StatusInternalServerError)
			return
		}

		log.Printf("Successfully wrote key: %s (%d bytes)", key, len(value))
		w.WriteHeader(http.StatusOK)
		fmt.Fprintf(w, "OK\n")
	}
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, "OK\n")
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
