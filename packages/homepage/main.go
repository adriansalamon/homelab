package main

import (
	"encoding/json"
	"html/template"
	"log"
	"net/http"
	"os"
	"os/signal"
	"path"
	"sync"
	"syscall"

	"github.com/BurntSushi/toml"
	"github.com/Masterminds/sprig/v3"
)

type ServiceMeta struct {
	Name        string `toml:"name"`
	Description string `toml:"description"`
	Icon        string `toml:"icon"`
	IconDark    string `toml:"icon_dark"`
	Category    string `toml:"category"`
	Color       string `toml:"color"`
	Path        string `toml:"path"`
}

type DiscoveredService struct {
	ID  string `json:"id"`
	URL string `json:"url"`
}

type Service struct {
	Name        string
	Description string
	URL         string
	Icon        string
	IconDark    string
	Color       string
	Path        string
}

type Config struct {
	mu         sync.RWMutex
	Services   map[string][]Service
	Categories []string // Ordered list of categories
	tmpl       *template.Template
}

func (c *Config) Load() error {
	c.mu.Lock()
	defer c.mu.Unlock()

	// Get config paths from env or use defaults
	configDirPath := os.Getenv("CONFIG_DIR")
	if configDirPath == "" {
		configDirPath = "."
	}

	// Load metadata with order preservation
	var metadata map[string]ServiceMeta
	metaData, err := toml.DecodeFile(path.Join(configDirPath, "services.toml"), &metadata)
	if err != nil {
		return err
	}

	// Extract keys in file order
	var orderedKeys []string
	for _, key := range metaData.Keys() {
		if len(key) == 1 {
			orderedKeys = append(orderedKeys, key[0])
		}
	}

	// Load discovered services
	data, err := os.ReadFile(path.Join(configDirPath, "config.json"))
	if err != nil {
		return err
	}

	var discovered struct {
		Services []DiscoveredService `json:"services"`
	}
	if err := json.Unmarshal(data, &discovered); err != nil {
		return err
	}

	// Create lookup map for discovered services
	discoveredMap := make(map[string]DiscoveredService)
	for _, d := range discovered.Services {
		discoveredMap[d.ID] = d
	}

	// Merge in file order and group by category
	services := make(map[string][]Service)
	var categories []string
	categorySet := make(map[string]bool)

	for _, key := range orderedKeys {
		meta := metadata[key]
		if d, ok := discoveredMap[key]; ok {
			svc := Service{
				Name:        meta.Name,
				Description: meta.Description,
				URL:         d.URL,
				Icon:        meta.Icon,
				IconDark:    meta.IconDark,
				Color:       meta.Color,
				Path:        meta.Path,
			}
			services[meta.Category] = append(services[meta.Category], svc)

			// Track category order by first appearance
			if !categorySet[meta.Category] {
				categories = append(categories, meta.Category)
				categorySet[meta.Category] = true
			}
		}
	}

	// Load template
	tmpl := template.New("index.html").Funcs(sprig.FuncMap())
	tmpl, err = tmpl.ParseFiles("templates/index.html")
	if err != nil {
		return err
	}

	c.Services = services
	c.Categories = categories
	c.tmpl = tmpl

	log.Println("Configuration loaded successfully")
	return nil
}

func (c *Config) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	c.mu.RLock()
	defer c.mu.RUnlock()

	data := struct {
		Categories []string
		Services   map[string][]Service
	}{
		Categories: c.Categories,
		Services:   c.Services,
	}

	if err := c.tmpl.Execute(w, data); err != nil {
		log.Printf("Template execution error: %v", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
	}
}

func main() {
	config := &Config{}

	// Initial load
	if err := config.Load(); err != nil {
		log.Fatal("Failed to load config:", err)
	}

	// Setup SIGHUP reload
	sigs := make(chan os.Signal, 1)
	signal.Notify(sigs, syscall.SIGHUP)
	go func() {
		for range sigs {
			if err := config.Load(); err != nil {
				log.Printf("Failed to reload config: %v", err)
			}
		}
	}()

	// HTTP server
	http.Handle("/", config)

	addr := os.Getenv("ADDR")
	if addr == "" {
		addr = ":3000"
	}

	log.Printf("Listening on %s", addr)
	if err := http.ListenAndServe(addr, nil); err != nil {
		log.Fatal(err)
	}
}
