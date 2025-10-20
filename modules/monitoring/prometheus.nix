{
  lib,
  config,
  ...
}:
let
  inherit (config.node) name;
in
{

  options.meta.prometheus = {
    enable = lib.mkEnableOption "Enables basic Prometheus exporters, and registers them with Consul";
  };

  config = lib.mkIf config.meta.prometheus.enable {
    assertions = [
      {
        assertion = config.services.consul.enable;
        message = "You must enable Consul to use the Prometheus module";
      }
    ];

    # enable the node exporter
    services.prometheus.exporters.node = {
      enable = true;
      enabledCollectors = [ "systemd" ];
    };

    # register it in Consul
    consul.services."${name}-node-exporter" = {
      inherit (config.services.prometheus.exporters.node) port;
      tags = [ "prometheus.scrape=true" ];
    };

    # allow the prometheus scrape server to access
    globals.nebula.mesh.hosts.${name}.firewall.inbound = [
      {
        port = builtins.toString config.services.prometheus.exporters.node.port;
        proto = "tcp";
        host = "zeus-prometheus";
      }
    ];
  };
}
