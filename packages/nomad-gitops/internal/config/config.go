package config

import (
	"log/slog"
	"time"

	"github.com/caarlos0/env/v11"
)

type Config struct {
	GitURL           string        `env:"GIT_URL,required"`
	GitBranch        string        `env:"GIT_BRANCH"`
	GitSyncInterval  time.Duration `env:"GIT_SYNC_INTERVAL"`
	NomadJobPaths    []string      `env:"NOMAD_JOB_PATHS,required"`
	ConsulPrefix     string        `env:"CONSUL_PREFIX"`
	PushoverUserKey  string        `env:"PUSHOVER_USER_KEY"`
	PushoverAPIToken string        `env:"PUSHOVER_API_TOKEN"`
	LogLevel         slog.Level    `env:"LOG_LEVEL"`
}

// Needed env variables automatically fetched by Consul and Nomad API clients:
// NOMAD_ADDR
// NOMAD_TOKEN
// CONSUL_ADDR
// CONSUL_HTTP_TOKEN

func LoadConfig() (*Config, error) {
	// Defaults
	cfg := Config{
		GitBranch:       "main",
		GitSyncInterval: time.Minute * 5,
		LogLevel:        slog.LevelInfo,
		NomadJobPaths:   []string{"nomad/jobs/**/*.nomad"},
		ConsulPrefix:    "nomad-gitops",
	}

	err := env.Parse(&cfg)
	if err != nil {
		return nil, err
	}

	return &cfg, nil
}
