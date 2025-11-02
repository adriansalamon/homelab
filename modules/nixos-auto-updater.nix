{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.nixos-auto-updater;
in
{
  options.services.nixos-auto-updater = with lib; {
    enable = mkEnableOption "NixOS Auto Updater";

    checkInterval = mkOption {
      type = types.str;
      default = "daily";
      description = "How often to check for updates (systemd timer format: daily, hourly, *-*-* 02:00:00, etc.)";
    };

    consulAddr = mkOption {
      type = types.str;
      default = "127.0.0.1:8500";
      description = "Consul HTTP API address";
    };

    consulTokenFile = mkOption {
      type = types.path;
      description = "Path to file containing Consul HTTP authentication token";
    };

    pushoverUserFile = mkOption {
      type = types.path;
      description = "Path to file containing Pushover user key";
    };

    pushoverAppFile = mkOption {
      type = types.path;
      description = "Path to file containing Pushover app token";
    };

    lockTimeout = mkOption {
      type = types.str;
      default = "1h";
      description = "Consul session lock timeout";
    };

    healthTimeout = mkOption {
      type = types.str;
      default = "30s";
      description = "Timeout for health checks after deployment";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      nixos-auto-updater
      nix
    ];

    # Create the systemd service (runs once per timer trigger)
    systemd.services.nixos-auto-updater = {
      description = "NixOS Auto Updater";
      after = [
        "network-online.target"
        "consul.service"
      ];
      wants = [ "network-online.target" ];

      environment = {
        CONSUL_HTTP_ADDR = cfg.consulAddr;
        LOCK_TIMEOUT = cfg.lockTimeout;
        HEALTH_TIMEOUT = cfg.healthTimeout;
      };

      script = ''
        export CONSUL_HTTP_TOKEN=$(cat ${cfg.consulTokenFile})
        export PUSHOVER_USER=$(cat ${cfg.pushoverUserFile})
        export PUSHOVER_APP=$(cat ${cfg.pushoverAppFile})
        exec ${pkgs.nixos-auto-updater}/bin/nixos-auto-updater
      '';

      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };

      path = [ pkgs.nix ];
    };

    # Create the systemd timer to trigger periodic checks
    systemd.timers.nixos-auto-updater = {
      description = "NixOS Auto Updater Timer";
      timerConfig = {
        OnBootSec = "5min";
        OnCalendar = cfg.checkInterval;
        Persistent = true;
        AccuracySec = "1min";
        RandomizedDelaySec = "10min";
      };
      wantedBy = [ "timers.target" ];
    };
  };
}
