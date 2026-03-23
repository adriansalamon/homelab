{
  globals,
  config,
  lib,
  ...
}:
let
  host = config.node.name;
  nebulaIp = globals.nebula.mesh.hosts.${host}.ipv4;

  port = 8428;
in
{

  environment.persistence."/state".directories = lib.singleton {
    directory = "/var/lib/private/${config.services.victoriametrics.stateDir}";
    mode = "0700";
  };

  services.victoriametrics = {
    enable = true;
    listenAddress = "${nebulaIp}:${toString port}";
    retentionPeriod = "3M";
    extraOptions = [
      "-vmalert.proxyURL=http://vmalert.service.consul:13691"
    ];
  };

  consul.services.victoriametrics = {
    inherit port;

    tags = [
      "traefik.enable=true"
      "traefik.http.routers.victoriametrics.rule=Host(`vmetrics.local.${globals.domains.main}`)"
      "prometheus.scrape=true"
    ];

    check = {
      http = "http://${nebulaIp}:${toString port}/health";
      interval = "10s";
      timeout = "5s";
    };
  };

  globals.nebula.mesh.hosts.${host} = {
    groups = [ "vmetrics" ];

    # todo: fix rules/groups
    firewall.inbound = [
      {
        inherit port;
        proto = "tcp";
        group = "prometheus";
      }
      {
        inherit port;
        proto = "tcp";
        group = "consul-client";
      }
      {
        inherit port;
        proto = "tcp";
        group = "reverse-proxy";
      }
      {
        inherit port;
        proto = "tcp";
        group = "grafana";
      }
    ];
  };
}
