package main

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/cenkalti/backoff/v5"
	"github.com/hashicorp/consul/api"
	consul "github.com/hashicorp/consul/api"
)

type Updater struct {
	consul   *consul.Client
	config   Config
	logger   *slog.Logger
	pushover *PushoverClient
}

func NewUpdater(consul *consul.Client, config Config, logger *slog.Logger, pushover *PushoverClient) *Updater {
	return &Updater{
		consul:   consul,
		config:   config,
		logger:   logger,
		pushover: pushover,
	}
}

func (u *Updater) CheckAndUpdate(ctx context.Context) {
	u.logger.Info("Checking for updates")
	checkKey := "builds/auto-updater-enabled"
	pair, _, err := u.consul.KV().Get(checkKey, nil)
	if err != nil {
		u.logger.Error("Failed to query Consul KV", "error", err, "key", checkKey)
		u.notify(fmt.Sprintf("Failed to query Consul KV: %v", err), true)
		return
	}

	if pair != nil && string(pair.Value) != "true" {
		u.logger.Info("Auto updater is disabled")
		return
	}

	// Query Consul KV for latest derivation
	kvKey := fmt.Sprintf("builds/nixos-system-%s", u.config.Hostname)
	pair, _, err = u.consul.KV().Get(kvKey, nil)
	if err != nil {
		u.logger.Error("Failed to query Consul KV", "error", err, "key", kvKey)
		u.notify(fmt.Sprintf("Failed to query Consul KV: %v", err), true)
		return
	}

	if pair == nil {
		u.logger.Info("No derivation found in Consul KV", "key", kvKey)
		return
	}

	latestDerivation := string(pair.Value)
	u.logger.Info("Latest derivation from Consul", "derivation", latestDerivation)

	currentDerivation, err := u.getCurrentDerivation()
	if err != nil {
		u.logger.Error("Failed to get current derivation", "error", err)
		return
	}

	u.logger.Info("Current derivation", "derivation", currentDerivation)

	// Compare
	if latestDerivation == currentDerivation {
		u.logger.Info("System is up to date")
		return
	}

	u.logger.Info("New derivation available, attempting update")

	// Try to acquire lock with exponential backoff
	u.deployWithLock(ctx, currentDerivation, latestDerivation)
}

func (u *Updater) deployWithLock(ctx context.Context, currentDerivation, derivation string) {
	lockKey := "builds/activate-lock"
	lockName := fmt.Sprintf("updater-%s-%d", u.config.Hostname, time.Now().UnixNano())

	// Acquire lock with exponential backoff: 1s initial, 1h max
	b := backoff.NewExponentialBackOff()
	b.InitialInterval = 1 * time.Second
	b.MaxInterval = 1 * time.Hour

	session, err := backoff.Retry(ctx, func() (string, error) {
		u.logger.Debug("Attempting to acquire lock")
		return u.acquireSessionLock(lockKey, lockName)
	})

	if err != nil {
		u.logger.Error("Failed to acquire lock", "error", err)
		u.notify(fmt.Sprintf("Failed to acquire deployment lock on %s: %v", u.config.Hostname, err), true)
		return
	}

	defer u.releaseSessionLock(session)

	u.logger.Info("Lock acquired, proceeding with deployment")
	if err := u.deploy(ctx, currentDerivation, derivation); err != nil {
		u.logger.Error("Deployment failed", "error", err)
		u.notify(fmt.Sprintf("Deployment failed on %s: %v", u.config.Hostname, err), true)
		return
	}

	u.logger.Info("Deployment successful")
	u.notify(fmt.Sprintf("Deployment successful on %s", u.config.Hostname), false)
}

func (u *Updater) deploy(ctx context.Context, currentDerivation, derivation string) error {
	u.logger.Info("Building derivation", "derivation", derivation)
	if err := u.buildDerivation(ctx, derivation); err != nil {
		return fmt.Errorf("build failed: %w", err)
	}

	u.logger.Info("Setting profile", "derivation", derivation)
	if err := u.setProfile(derivation); err != nil {
		return fmt.Errorf("set profile failed: %w", err)
	}

	u.logger.Info("Switching configuration")
	if err := u.switchConfiguration(derivation); err != nil {
		u.logger.Error("Switch configuration failed, rolling back", "error", err)
		if rollbackErr := u.rollback(currentDerivation); rollbackErr != nil {
			return fmt.Errorf("switch failed: %w, rollback also failed: %w", err, rollbackErr)
		}
		return fmt.Errorf("switch failed and rolled back: %w", err)
	}

	u.logger.Info("Waiting for health checks")
	if err := u.waitForHealth(ctx); err != nil {
		u.logger.Error("Health check failed, rolling back", "error", err)
		if rollbackErr := u.rollback(currentDerivation); rollbackErr != nil {
			return fmt.Errorf("health check failed: %w, rollback also failed: %w", err, rollbackErr)
		}
		return fmt.Errorf("health check failed and rolled back: %w", err)
	}

	u.logger.Info("Deployment completed successfully")
	return nil
}

func (u *Updater) buildDerivation(ctx context.Context, derivation string) error {
	cmd := exec.CommandContext(ctx, "nix", "build", derivation)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func (u *Updater) setProfile(derivation string) error {
	cmd := exec.Command("nix-env",
		"-p", "/nix/var/nix/profiles/system",
		"--set", derivation,
	)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func (u *Updater) switchConfiguration(derivation string) error {
	cmd := exec.Command(fmt.Sprintf("%s/bin/switch-to-configuration", derivation), "switch")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func (u *Updater) rollback(currentDerivation string) error {
	u.logger.Info("Rolling back to previous generation")
	if err := u.setProfile(currentDerivation); err != nil {
		return fmt.Errorf("failed to set previous profile: %w", err)
	}

	// Get all previous generations
	cmd := exec.Command("nix-env",
		"-p", "/nix/var/nix/profiles/system",
		"--list-generations",
	)
	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("failed to list generations: %w", err)
	}

	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	if len(lines) < 2 {
		return fmt.Errorf("not enough generations to rollback")
	}

	var lastGenNumber string
	for i := len(lines) - 2; i >= 0; i-- {
		fields := strings.Fields(lines[i])
		if len(fields) > 0 {
			lastGenNumber = fields[0]
			break
		}
	}

	if lastGenNumber == "" {
		return fmt.Errorf("could not determine previous generation")
	}

	u.logger.Info("Deleting bad generation and activating previous one", "generation", lastGenNumber)

	// Activate the previous generation
	activateCmd := exec.Command("nix-env",
		"-p", "/nix/var/nix/profiles/system",
		"--switch-generation", lastGenNumber,
	)
	if err := activateCmd.Run(); err != nil {
		return fmt.Errorf("failed to switch to previous generation: %w", err)
	}

	// Delete the latest (bad) generation
	deleteCmd := exec.Command("nix-env",
		"-p", "/nix/var/nix/profiles/system",
		"--delete-generations", "old",
	)
	if err := deleteCmd.Run(); err != nil {
		u.logger.Warn("Failed to delete old generations", "error", err)
		// Don't fail here, continue with rollback
	}

	// Switch configuration to activate it
	switchCmd := exec.Command(fmt.Sprintf("%s/bin/switch-to-configuration", currentDerivation), "switch")
	switchCmd.Stdout = os.Stdout
	switchCmd.Stderr = os.Stderr
	if err := switchCmd.Run(); err != nil {
		return fmt.Errorf("failed to switch configuration on rollback: %w", err)
	}

	return nil
}

func (u *Updater) getCurrentDerivation() (string, error) {
	target, err := os.Readlink("/run/current-system")
	if err != nil {
		return "", fmt.Errorf("failed to read current system link: %w", err)
	}

	return filepath.Clean(target), nil
}

func (u *Updater) waitForHealth(ctx context.Context) error {
	deadline, cancel := context.WithTimeout(ctx, u.config.HealthTimeout)
	defer cancel()

	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-deadline.Done():
			return fmt.Errorf("health check timeout")
		case <-ticker.C:
			if err := u.checkHealth(); err == nil {
				return nil
			}
		}
	}
}

func (u *Updater) checkHealth() error {
	leader, err := u.consul.Status().Leader()
	if err != nil {
		return fmt.Errorf("consul agent check failed: %w", err)
	}

	if leader == "" {
		return fmt.Errorf("consul agent returned nil leader")
	}

	return nil
}

func (u *Updater) acquireSessionLock(key, sessionName string) (string, error) {
	// Create a session
	entry := &api.SessionEntry{
		Name:     sessionName,
		TTL:      u.config.LockTimeout.String(),
		Behavior: api.SessionBehaviorDelete,
	}

	sessionID, _, err := u.consul.Session().Create(entry, nil)
	if err != nil {
		return "", err
	}

	u.logger.Info("Created session lock", "session_id", sessionID)

	// Try to acquire lock
	lockEntry := &api.KVPair{
		Key:     key,
		Value:   []byte(sessionID),
		Session: sessionID,
	}

	acquired, _, err := u.consul.KV().Acquire(lockEntry, nil)
	if err != nil {
		u.consul.Session().Destroy(sessionID, nil)
		return "", err
	}

	if !acquired {
		u.consul.Session().Destroy(sessionID, nil)
		return "", fmt.Errorf("lock already held")
	}

	return sessionID, nil
}

func (u *Updater) releaseSessionLock(sessionID string) error {
	u.logger.Info("Releasing lock", "session_id", sessionID)
	_, err := u.consul.Session().Destroy(sessionID, nil)
	return err
}

func (u *Updater) notify(message string, isError bool) {
	if u.pushover == nil {
		return
	}

	priority := "-1"

	title := "NixOS Auto Updater"
	if isError {
		title = "NixOS Auto Updater - Error"
		priority = "0"
	}

	if err := u.pushover.Send(title, message, priority); err != nil {
		u.logger.Error("Failed to send Pushover notification", "error", err)
	}
}
