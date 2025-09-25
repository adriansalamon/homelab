package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"regexp"
)

func webFingerHandler(domain string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		resource := r.URL.Query().Get("resource")
		if resource == "" {
			http.Error(w, "Missing resource parameter", http.StatusBadRequest)
			return
		}

		re := regexp.MustCompile(`^acct:(.*@` + regexp.QuoteMeta(domain) + `)$`)
		match := re.FindStringSubmatch(resource)

		if match != nil {
			response := map[string]any{
				"subject": resource,
				"links": []map[string]string{
					{
						"rel":  "http://openid.net/specs/connect/1.0/issuer",
						"href": fmt.Sprintf("https://auth.%s", domain),
					},
				},
			}

			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusOK)
			json.NewEncoder(w).Encode(response)
			return
		}

		http.NotFound(w, r)
	}
}

func main() {

	addr := os.Getenv("ADDR")
	if addr == "" {
		addr = ":9090"
	}

	domain := os.Getenv("DOMAIN")
	if domain == "" {
		fmt.Println("DOMAIN environment variable is not set")
		os.Exit(1)
	}

	http.HandleFunc("/.well-known/webfinger", webFingerHandler(domain))

	fmt.Printf("Starting WebFinger server for domain %s on addr %s...\n", domain, addr)
	if err := http.ListenAndServe(addr, nil); err != nil {
		fmt.Println("Error starting server:", err)
	}
}
