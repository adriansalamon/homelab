{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    mkIf
    mkEnableOption
    mkOption
    types
    ;

  cfg = config.services.kea-ddns-consul;
in
{
  options.services.kea-ddns-consul = mkOption {
    default = { };
    type = types.submodule {
      options = {
        enable = mkEnableOption "KEA DDNS to Consul service";

        consulTokenFile = mkOption {
          type = types.path;
          description = "Path to the Consul token file";
        };

        consulUrl = mkOption {
          type = types.str;
          description = "URL of the Consul server";
          default = "http://127.0.0.1:8500";
        };

        siteName = mkOption {
          type = types.str;
          description = "Site name identifier for this kea-ddns instance";
        };

        cleanupInterval = mkOption {
          type = types.str;
          description = "Interval for cleanup of expired services (Go duration format, e.g. '1h', '30m')";
          default = "1h";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    users.groups.kea-ddns-consul = { };
    users.users.kea-ddns-consul = {
      isSystemUser = true;
      group = "kea-ddns-consul";
    };

    systemd.services.kea-ddns-consul = {
      description = "Kea DDNS to consul service";
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = "${pkgs.kea-ddns-consul}/bin/kea-ddns-consul";
        Restart = "always";
        User = "kea-ddns-consul";
        Group = "kea-ddns-consul";
        NoNewPrivileges = true;
      };

      environment = {
        CONSUL_TOKEN_FILE = cfg.consulTokenFile;
        CONSUL_URL = cfg.consulUrl;
        SITE_NAME = cfg.siteName;
        CLEANUP_INTERVAL = cfg.cleanupInterval;
      };
    };
  };
}
