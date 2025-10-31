# NixOS Auto Updater

A Go service that automatically updates NixOS systems with Consul-based coordination to prevent all systems from updating simultaneously.

- Queries Consul KV for the latest NixOS system derivation (`/builds/nixos-system-{hostname}`)
- Compares it with the current system
- If different:
  - Acquires a global Consul session lock (`/builds/activate-lock`)
  - Builds the derivation, from cache
  - Verifies Consul agent health
  - Releases the lock
  - Sends notifications via Pushover

## Usage

```nix
{
  services.nixos-auto-updater = {
    enable = true;
    checkInterval = "daily";
    consulAddr = "127.0.0.1:8500";
    lockTimeout = "1h";
    healthTimeout = "30s";
    consulTokenFile = "/run/secrets/consul-token";
    pushoverUserFile = "/run/secrets/pushover-user";
    pushoverAppFile = "/run/secrets/pushover-app";
  };
}
```

## Configuration

- `checkInterval`: Systemd calendar format (default: `"daily"`)
- `consulAddr`: Consul API address (default: `"127.0.0.1:8500"`)
- `lockTimeout`: Consul session TTL (default: `"1h"`)
- `healthTimeout`: Health check timeout (default: `"30s"`)
- `consulTokenFile`: Path to file containing Consul token (optional)
- `pushoverUserFile`: Path to file containing Pushover user key (optional)
- `pushoverAppFile`: Path to file containing Pushover app token (optional)

Secret files contain raw values (one per file):

```
# /run/secrets/pushover-user
u123456789...

# /run/secrets/pushover-app
a123456789...
```

## Logs

```bash
journalctl -u nixos-auto-updater -f
systemctl list-timers nixos-auto-updater
```
