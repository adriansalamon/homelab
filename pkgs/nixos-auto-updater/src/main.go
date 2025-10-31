package main

import (
	"context"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/caarlos0/env/v11"
	consul "github.com/hashicorp/consul/api"
)

type Config struct {
	Hostname      string        `env:"HOSTNAME" envDefault:""`
	ConsulAddr    string        `env:"CONSUL_HTTP_ADDR" envDefault:"127.0.0.1:8500"`
	ConsulToken   string        `env:"CONSUL_HTTP_TOKEN" envDefault:""`
	PushoverUser  string        `env:"PUSHOVER_USER" envDefault:""`
	PushoverApp   string        `env:"PUSHOVER_APP" envDefault:""`
	LockTimeout   time.Duration `env:"LOCK_TIMEOUT" envDefault:"1h"`
	HealthTimeout time.Duration `env:"HEALTH_TIMEOUT" envDefault:"30s"`
}

func main() {
	logger := slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelDebug,
	}))
	slog.SetDefault(logger)

	config := loadConfig()

	slog.Info("Starting nixos-auto-updater",
		"hostname", config.Hostname,
		"consul_addr", config.ConsulAddr,
	)

	ctx, cancel := context.WithCancel(context.Background())
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigChan
		slog.Info("Received shutdown signal")
		cancel()
	}()

	consulClient, err := consul.NewClient(&consul.Config{
		Address: config.ConsulAddr,
		Token:   config.ConsulToken,
	})
	if err != nil {
		slog.Error("Failed to create Consul client", "error", err)
		os.Exit(1)
	}

	var pushoverClient *PushoverClient
	if config.PushoverUser != "" && config.PushoverApp != "" {
		var err error
		pushoverClient, err = NewPushoverClient(config.PushoverUser, config.PushoverApp)
		if err != nil {
			slog.Error("Failed to create Pushover client", "error", err)
			os.Exit(1)
		}
	}

	updater := NewUpdater(consulClient, config, logger, pushoverClient)

	updater.CheckAndUpdate(ctx)
	slog.Info("Update check complete")
}

func loadConfig() Config {
	cfg := Config{}
	if err := env.Parse(&cfg); err != nil {
		slog.Error("Failed to parse config", "error", err)
		os.Exit(1)
	}

	// If hostname is not set via env, try to get from system
	if cfg.Hostname == "" {
		hostname, err := os.Hostname()
		if err != nil {
			slog.Error("Failed to determine hostname", "error", err)
			os.Exit(1)
		}
		cfg.Hostname = hostname
	}

	return cfg
}
