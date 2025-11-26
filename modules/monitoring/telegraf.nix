{
  config,
  lib,
  pkgs,
  globals,
  ...
}:
let
  inherit (lib)
    concatLists
    flip
    mapAttrsToList
    mkEnableOption
    mkIf
    mkOption
    optionalAttrs
    optional
    toList
    types
    ;

  name = config.node.name;
  cfg = config.meta.telegraf;

  mkIfNotEmpty = xs: mkIf (xs != [ ]) xs;

  nixInfoScript = pkgs.writeShellScript "nix-info" ''
    set -euo pipefail

    # Get system derivation path (runtime)
    SYSTEM_DRV=$(readlink /run/current-system 2>/dev/null || echo "unknown")
    KERNEL=$(uname -rs 2>/dev/null || echo "unknown")
    NIX_VERSION=$(${pkgs.nix}/bin/nix-env --version 2>/dev/null || echo "unknown")

    # Build-time configuration
    NIXOS_VERSION="${config.system.nixos.version}"
    PLATFORM="${config.nixpkgs.system}"

    ${pkgs.jq}/bin/jq -n \
      --arg platform "$PLATFORM" \
      --arg system_drv "$SYSTEM_DRV" \
      --arg kernel "$KERNEL" \
      --arg nix_version "$NIX_VERSION" \
      --arg nixos_version "$NIXOS_VERSION" \
      '{
        platform: $platform,
        system_drv: $system_drv,
        kernel: $kernel,
        nix_version: $nix_version,
        nixos_version: $nixos_version,
        value: 1
      }'
  '';
in
{

  options.meta.telegraf = {
    enable = mkEnableOption "Enables basic Telegraf metrics collection, and registers them as prometheus scrape jobs with Consul";

    avilableMonitoringNetworks = mkOption {
      type = types.listOf lib.types.str;
      example = [ "internet" ];
      description = ''
        All of the global monitoring networks in this list will
        automatically be monitored by this node. Includes `local-$\{node.name}`
        by default.
      '';
    };

    port = mkOption {
      type = types.port;
      default = 9273;
      description = "The port to expose prprometheus metrics on";
    };
  };

  config = mkIf cfg.enable {
    meta.telegraf.avilableMonitoringNetworks = [ "local-${name}" ];

    assertions = [
      {
        assertion = config.services.consul.enable;
        message = "You must enable Consul to use the Telegraf module";
      }
    ];

    services.telegraf = {
      enable = true;

      extraConfig = {
        outputs.prometheus_client = {
          listen = ":${toString cfg.port}";
        };

        inputs = {
          conntrack = { };
          cpu = { };
          disk = { };
          diskio = { };
          internal = { };
          interrupts = { };
          kernel = { };
          kernel_vmstat = { };
          linux_sysctl_fs = { };
          mem = { };
          net = {
            ignore_protocol_stats = true;
          };
          netstat = { };
          nstat = { };
          processes = { };
          swap = { };
          system = { };
          systemd_units = {
            unittype = "service";
          };
          temp = { };

          exec = [
            {
              name_suffix = "_nix_info";
              interval = "10m";
              commands = [ nixInfoScript ];
              data_format = "json";
              json_string_fields = [
                "platform"
                "system_drv"
                "kernel"
                "nix_version"
                "nixos_version"
              ];
            }
          ]
          ++ lib.optionals (builtins.hasAttr "zfs" config.boot.supportedFilesystems) [
            {
              name_suffix = "_zpool_list";
              commands = [ "${pkgs.zfs}/bin/zpool list --json --json-int" ];
              data_format = "json";
              json_query = "pools.@values.#.{name,state,allocated:properties.allocated.value,capacity:properties.capacity.value,dedupratio:properties.dedupratio.value,fragmentation:properties.fragmentation.value,free:properties.free.value,health:properties.health.value,size:properties.size.value}";
              json_string_fields = [
                "state"
                "dedupratio"
                "health"
              ];
              tag_keys = [ "name" ];
            }
            {
              name_suffix = "_zfs_list";
              commands = [ "${pkgs.zfs}/bin/zfs list --json --json-int" ];
              data_format = "json";
              json_query = "datasets.@values.#.{name,pool,used:properties.used.value,available:properties.available.value,referenced:properties.referenced.value}";
              json_string_fields = [ "pool" ];
              tag_keys = [ "name" ];
            }
          ];

          ping = mkIfNotEmpty (
            concatLists (
              flip mapAttrsToList globals.monitoring.ping (
                name: pingCfg:
                optional (builtins.elem pingCfg.network cfg.avilableMonitoringNetworks) {
                  interval = "1m";
                  method = "native";
                  urls = [ pingCfg.ipv4addr ];
                  ipv4 = true;
                  ipv6 = false;
                  tags = {
                    inherit name;
                    inherit (pingCfg) network;
                  };
                  fieldinclude = [
                    "percent_packet_loss"
                    "average_response_ms"
                  ];
                }
              )
            )
          );

          dns_query = mkIfNotEmpty (
            concatLists (
              flip mapAttrsToList globals.monitoring.dns (
                name: dnsCfg:
                optional (builtins.elem dnsCfg.network cfg.avilableMonitoringNetworks) {
                  interval = "1m";
                  servers = [ dnsCfg.server ];
                  domains = [ dnsCfg.domain ];
                  record_type = dnsCfg.recordType;
                  tags = {
                    inherit name;
                    inherit (dnsCfg) network;
                  };
                }
              )
            )
          );

          http_response = mkIfNotEmpty (
            concatLists (
              flip mapAttrsToList globals.monitoring.http (
                name: httpCfg:
                optional (builtins.elem httpCfg.network cfg.avilableMonitoringNetworks) {
                  interval = "1m";
                  urls = toList httpCfg.url;
                  method = "GET";
                  response_status_code = httpCfg.expectedStatus;
                  response_string_match = mkIf (httpCfg.expectedBodyRegex != null) httpCfg.expectedBodyRegex;
                  follow_redirects = true;
                  tags = {
                    inherit name;
                    inherit (httpCfg) network;
                  };
                }
              )
            )
          );

          net_response = mkIfNotEmpty (
            concatLists (
              flip mapAttrsToList globals.monitoring.tcp (
                name: tcpCfg:
                optional (builtins.elem tcpCfg.network cfg.avilableMonitoringNetworks) {
                  interval = "1m";
                  protocol = "tcp";
                  address = "${tcpCfg.host}:${toString tcpCfg.port}";
                  tags = {
                    inherit name;
                    inherit (tcpCfg) network;
                  };
                  fieldexclude = [
                    "result_type"
                    "string_found"
                  ];
                }
              )
            )
          );
        }
        // optionalAttrs (builtins.hasAttr "zfs" config.boot.supportedFilesystems) {
          zfs = { };
        };
      };
    };

    # register it in Consul
    consul.services."telegraf" = {
      inherit (cfg) port;
      tags = [ "prometheus.scrape=true" ];
    };

    # allow the prometheus scrape server to access
    globals.nebula.mesh.hosts.${name}.firewall.inbound = [
      {
        inherit (cfg) port;
        proto = "tcp";
        host = "zeus-prometheus";
      }
    ];
  };
}
