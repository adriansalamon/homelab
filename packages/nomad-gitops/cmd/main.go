package main

import (
	"context"
	"log/slog"
	"nomad-gitops/internal/config"
	"nomad-gitops/internal/consul"
	"nomad-gitops/internal/git"
	"nomad-gitops/internal/nomad"
	"nomad-gitops/internal/notification"
	"nomad-gitops/internal/reconcile"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func main() {
	// Load config
	cfg, err := config.LoadConfig()
	if err != nil {
		slog.Error("failed to load config", "error", err)
		os.Exit(1)
	}

	logger := slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{
		Level: cfg.LogLevel,
	}))
	slog.SetDefault(logger)

	slog.Info("nomad-gitops starting",
		"git_url", cfg.GitURL,
		"git_branch", cfg.GitBranch,
		"sync_interval", cfg.GitSyncInterval,
		"job_paths", cfg.NomadJobPaths)

	// Initialize clients
	nomadClient, err := nomad.New()
	if err != nil {
		slog.Error("failed to create nomad client", "error", err)
		os.Exit(1)
	}

	consulState, err := consul.New(cfg.ConsulPrefix)
	if err != nil {
		slog.Error("failed to create consul client", "error", err)
		os.Exit(1)
	}

	// notifier := notification.NewPushover(cfg.PushoverUserKey, cfg.PushoverAPIToken)
	notifier := notification.NewDummyNotifier()

	// Initialize git repo
	gitRepo := git.New(cfg)
	if err := gitRepo.Init(context.Background()); err != nil {
		slog.Error("failed to initialize git repository", "error", err)
		os.Exit(1)
	}

	reconciler := reconcile.New(
		nomadClient,
		gitRepo,
		consulState,
		notifier,
		cfg.NomadJobPaths,
		logger,
	)

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	ticker := time.NewTicker(cfg.GitSyncInterval)
	defer ticker.Stop()

	// Run reconciliation immediately on startup
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	result, err := reconciler.Reconcile(ctx)
	cancel()
	if err != nil {
		slog.Error("initial reconciliation failed", "error", err)
	} else {
		slog.Info("initial reconciliation complete",
			"created", len(result.Created),
			"updated", len(result.Updated),
			"deleted", len(result.Deleted),
			"errors", len(result.Errors))
	}

	// Loop
	for {
		select {
		case <-sigChan:
			slog.Info("shutdown signal received")
			return

		case <-ticker.C:
			ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
			result, err := reconciler.Reconcile(ctx)
			cancel()

			if err != nil {
				slog.Error("reconciliation failed", "error", err)
			} else {
				if len(result.Created) > 0 || len(result.Updated) > 0 || len(result.Deleted) > 0 {
					slog.Info("reconciliation complete",
						"created", len(result.Created),
						"updated", len(result.Updated),
						"deleted", len(result.Deleted))
				} else {
					slog.Debug("reconciliation complete - no changes")
				}

				if len(result.Errors) > 0 {
					slog.Error("reconciliation had errors", "errors", result.Errors)
				}
			}
		}
	}
}
