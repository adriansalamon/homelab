{
  config,
  lib,
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
