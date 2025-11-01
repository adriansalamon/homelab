{ config, globals, ... }:
{
  # Important, but not critical for backups?
  environment.persistence."/state".directories = [
    {
      directory = "/var/lib/${config.services.prometheus.stateDir}";
      user = "prometheus";
      mode = "0700";
    }
  ];

  services.prometheus = {
    enable = true;

    scrapeConfigs = [
      {
        job_name = "consul";
        consul_sd_configs = [
          {
            server = "127.0.0.1:8500";
            tags = [ "prometheus.scrape=true" ];
            #filter = ''"prometheus.scrape=true" in ServiceTags'';
          }
        ];
        tls_config = {
          insecure_skip_verify = true;
        };
        relabel_configs = [
          {
            source_labels = [ "__meta_consul_node" ];
            replacement = "$1";
            target_label = "instance";
          }
          {
            source_labels = [ "__meta_consul_tags" ];
            regex = ".*,prometheus.path=([^,]*),.*";
            replacement = "$1";
            target_label = "__metrics_path__";
          }
          {
            source_labels = [ "__meta_consul_tags" ];
            regex = ".*,prometheus.scheme=([^,]*),.*";
            target_label = "__scheme__";
            replacement = "$1";
          }
        ];
      }
    ];
  };

  globals.nebula.mesh.hosts.zeus-prometheus.firewall.inbound = [
    # for the web interface
    {
      port = "9090";
      proto = "tcp";
      group = "reverse-proxy";
    }
    # for grafana API access
    {
      port = "9090";
      proto = "tcp";
      host = "zeus-grafana";
    }
  ];

  consul.services.prometheus = {
    inherit (config.services.prometheus) port;
    tags = [
      "traefik.enable=true"
      "traefik.http.routers.prometheus.rule=Host(`prometheus.local.${globals.domains.main}`)"
      "traefik.http.routers.prometheus.middlewares=authelia"
    ];
  };
}
