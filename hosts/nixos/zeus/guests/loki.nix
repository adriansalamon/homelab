{ config, globals, ... }:
let
  lokiDir = "/var/lib/loki";
in
{
  microvm.vcpu = 4;
  microvm.mem = 1024 * 4;

  # Important, but not critical for backups?
  environment.persistence."/state".directories = [
    {
      directory = "/var/lib/loki";
      user = "loki";
      group = "loki";
      mode = "0700";
    }
  ];

  age.secrets.loki-basic-auth-hashes = {
    mode = "440";
    group = "nginx";

    generator.dependencies = globals.loki-secrets;
    # Using actual hashes here, while safer, proved very slow for many small requests, like ingesting logs. We could try
    # bcrypt with fewer rounds also, but that's not really necessary.
    generator.script =
      {
        lib,
        decrypt,
        deps,
        ...
      }:
      lib.concatMapStrings (
        {
          name,
          host,
          file,
        }:
        ''
          echo "${lib.escapeShellArg host}"+"${lib.escapeShellArg name}:{PLAIN}$(${decrypt} ${lib.escapeShellArg file})" \
            || die "Failure while aggregating basic auth hashes"
        ''
      ) deps;

  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    proxyTimeout = "1800s";
    defaultListenAddresses = [ globals.nebula.mesh.hosts.zeus-loki.ipv4 ];

    virtualHosts."loki" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:3100";
        proxyWebsockets = true;
        basicAuthFile = config.age.secrets.loki-basic-auth-hashes.path;
        extraConfig = ''
          access_log off;
        '';
      };
    };
  };

  services.loki = {
    enable = true;
    configuration = {
      analytics.reporting_enabled = false;
      auth_enabled = false;

      server = {
        http_listen_port = 3100;
        http_listen_address = "127.0.0.1";
      };

      ingester = {
        lifecycler = {
          address = "127.0.0.1";
          ring = {
            kvstore.store = "inmemory";
            replication_factor = 1;
          };
          final_sleep = "0s";
        };
        chunk_idle_period = "5m";
        chunk_retain_period = "30s";
      };

      schema_config.configs = [
        {
          from = "2025-06-01";
          store = "tsdb";
          object_store = "filesystem";
          schema = "v13";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }
      ];

      storage_config = {
        tsdb_shipper = {
          active_index_directory = "${lokiDir}/tsdb-index";
          cache_location = "${lokiDir}/tsdb-cache";
          cache_ttl = "24h";
        };

        filesystem.directory = "${lokiDir}/chunks";
      };

      limits_config = {
        reject_old_samples = true;
        reject_old_samples_max_age = "168h";
        retention_period = "720h"; # 30 days
        max_query_lookback = "720h"; # 30 days
      };

      table_manager = {
        retention_deletes_enabled = false;
        retention_period = "0s";
      };

      compactor = {
        working_directory = lokiDir;
        compactor_ring.kvstore.store = "inmemory";
        retention_enabled = true;
        retention_delete_delay = "2h";
        compaction_interval = "10m";
      };
    };
  };

  globals.nebula.mesh.hosts.zeus-loki.firewall.inbound = [
    {
      port = 80;
      proto = "tcp";
      host = "any";
    }
  ];
}
