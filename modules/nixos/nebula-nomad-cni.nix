{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.nebula-nomad-agent;
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    types
    ;

  tomlFormat = pkgs.formats.toml { };
  yamlFormat = pkgs.formats.yaml { };

in
{
  options.services.nebula-nomad-agent = {
    enable = mkEnableOption "Nebula Nomad Agent";

    package = mkOption {
      type = types.package;
      default = pkgs.nebula-nomad-cni;
      description = "The nebula-nomad-cni package to use.";
    };

    socketPath = mkOption {
      type = types.str;
      default = "/var/run/nebula-cni.sock";
      description = "Path to the Unix socket for CNI plugin communication.";
    };

    consulAddr = mkOption {
      type = types.str;
      default = "127.0.0.1:8500";
      description = "Consul server address.";
    };

    nomadAddr = mkOption {
      type = types.str;
      default = "http://127.0.0.1:4646";
      description = "Nomad server address.";
    };

    caCertPath = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to the Nebula CA certificate.";
    };

    caKeyPath = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to the Nebula CA private key.";
    };

    defaultNebulaConfig = mkOption {
      type = types.attrs;
      default = { };
      description = "Default Nebula configuration template.";
    };

    certTTL = mkOption {
      type = types.str;
      default = "1h";
      description = "Certificate TTL duration (e.g., '1h', '24h').";
    };

    environmentFile = mkOption {
      type = types.path;
      description = "Path to the environment file for the agent. Can include:

      - CONSUL_HTTP_TOKEN
      - NOMAD_TOKEN
      ";
    };

    ipPool = {
      networkCIDR = mkOption {
        type = types.net.cidrv4;
        example = "10.42.0.0/16";
        description = "Network CIDR for the IP pool.";
      };

      rangeStart = mkOption {
        type = types.net.ipv4;
        example = "10.42.1.0";
        description = "Start of the IP allocation range.";
      };

      rangeEnd = mkOption {
        type = types.net.ipv4;
        example = "10.42.255.255";
        description = "End of the IP allocation range.";
      };
    };

    extraConfig = mkOption {
      type = types.attrs;
      default = { };
      description = "Extra configuration to merge into the agent config.";
    };
  };

  config = mkIf cfg.enable {

    # Systemd service
    systemd.services.nebula-nomad-agent =

      {
        description = "Nebula Nomad Agent";
        wantedBy = [ "multi-user.target" ];
        after = [
          "basic.target"
          "network.target"
        ];
        wants = [ "basic.target" ];

        serviceConfig =
          let
            configFile = tomlFormat.generate "agent.toml" (
              {
                socket_path = cfg.socketPath;
                consul_addr = cfg.consulAddr;
                nomad_addr = cfg.nomadAddr;
                nebula_config_path = yamlFormat.generate "nebula-config.yaml" cfg.defaultNebulaConfig;
                worker_binary_path = "${cfg.package}/bin/nebula-nomad-worker";
                cert_ttl = cfg.certTTL;
                ip_pool = {
                  network_cidr = cfg.ipPool.networkCIDR;
                  range_start = cfg.ipPool.rangeStart;
                  range_end = cfg.ipPool.rangeEnd;
                };
              }
              // cfg.extraConfig
            );
          in
          {
            Type = "simple";
            ExecStart = "${cfg.package}/bin/nebula-nomad-agent -config ${configFile}";
            Restart = "on-failure";
            RestartSec = "10s";

            EnvironmentFile = cfg.environmentFile;

            # Hardening
            DynamicUser = false;
            CapabilityBoundingSet = [
              "CAP_SYS_ADMIN"
              "CAP_NET_ADMIN"
              "CAP_NET_RAW"
            ];
            AmbientCapabilities = [
              "CAP_SYS_ADMIN"
              "CAP_NET_ADMIN"
              "CAP_NET_RAW"
            ];
            PrivateUsers = false;
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectSystem = true;
            ProtectHome = true;
          };
      };

    # Warnings for missing required configuration
    warnings =
      lib.optional (cfg.ipPool.networkCIDR == null || cfg.ipPool.networkCIDR == "")
        "services.nebula-nomad-agent.ipPool.networkCIDR is not set but required for the agent to function.";

    assertions = [
      {
        assertion = cfg.environmentFile != null;
        message = "<option>services.atticd.nebula-nomad-agent</option> is not set.";
      }
      {
        assertion = cfg.ipPool.networkCIDR != null && cfg.ipPool.networkCIDR != "";
        message = "<option>services.nebula-nomad-agent.ipPool.networkCIDR</option> must be set";
      }
      {
        assertion = cfg.ipPool.rangeStart != null && cfg.ipPool.rangeStart != "";
        message = "<option>services.nebula-nomad-agent.ipPool.rangeStart</option> must be set";
      }
      {
        assertion = cfg.ipPool.rangeEnd != null && cfg.ipPool.rangeEnd != "";
        message = "<option>services.nebula-nomad-agent.ipPool.rangeEnd</option> must be set";
      }
    ];
  };
}
