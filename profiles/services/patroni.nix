{
  config,
  pkgs,
  globals,
  lib,
  inputs,
  ...
}:
let
  nebulaIp = globals.nebula.mesh.hosts.${config.node.name}.ipv4;
  secretsDir = inputs.self.outPath + "/secrets/patroni";
in
{
  age.secrets = {
    patroni-superuser-password = {
      rekeyFile = "${secretsDir}/patroni-superuser-password.age";
      generator.script = "alnum";
      owner = config.services.patroni.user;
    };

    patroni-replication-password = {
      rekeyFile = "${secretsDir}/patroni-replication-password.age";
      generator.script = "alnum";
      owner = config.services.patroni.user;
    };

    patroni-consul-token = {
      rekeyFile = "${secretsDir}/patroni-consul-token.age";
      owner = config.services.patroni.user;
    };
  };

  services.patroni = {
    enable = true;
    scope = "homelab-cluster";
    name = config.node.name;
    postgresqlPackage = pkgs.postgresql_16;

    nodeIp = nebulaIp;

    settings = {
      consul = {
        host = "127.0.0.1:8500";
        register_service = true;
      };

      bootstrap = {
        dcs = {
          ttl = 30;
          loop_wait = 10;
          retry_timeout = 10;
          maximum_lag_on_failover = 1048576; # 1MB

          postgresql = {
            use_pg_rewind = true;
            parameters = {
              max_connections = 100;
              shared_buffers = "256MB";
            };
          };
        };

        initdb = [
          "encoding=UTF-8"
          "data-checksums"
        ];
      };

      postgresql = {
        authentication = {
          replication.username = "replicator";
          superuser.username = "postgres";
        };

        listen = lib.mkForce "127.0.0.1,${nebulaIp}:5432";

        pg_hba = [
          "host replication replicator ${globals.nebula.mesh.cidrv4} scram-sha-256"
          "host replication replicator 127.0.0.1/32 scram-sha-256"
          "host all all ${globals.nebula.mesh.cidrv4} scram-sha-256"
          "host all all 127.0.0.1/32 scram-sha-256"
        ];
      };

      tags = {
        failover_priority = "1";
      };
    };

    environmentFiles = {
      PATRONI_SUPERUSER_PASSWORD = config.age.secrets.patroni-superuser-password.path;
      PATRONI_REPLICATION_PASSWORD = config.age.secrets.patroni-replication-password.path;
      PATRONI_CONSUL_TOKEN = config.age.secrets.patroni-consul-token.path;
    };
  };

  # Todo: remove this once we have consul connect for all services
  globals.nebula.mesh.hosts.${config.node.name}.firewall.inbound = [
    {
      "port" = "5432";
      "proto" = "tcp";
      "host" = "any";
    }
  ];

  systemd.tmpfiles.rules = [
    "d /run/postgresql 0700 patroni patroni -"
  ];
}
