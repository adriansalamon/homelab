{
  config,
  pkgs,
  globals,
  nodes,
  lib,
  ...
}:
let
  inherit (lib)
    unique
    mapAttrsToList
    genAttrs'
    ;

  dbUsers = unique (mapAttrsToList (_: { owner, ... }: owner) globals.databases);
  nebulaIp = globals.nebula.mesh.hosts.${config.node.name}.ipv4;
in
{
  age.secrets = {
    patroni-superuser-password = {
      generator.script = "alnum";
      owner = config.services.patroni.user;
    };

    patroni-replication-password = {
      generator.script = "alnum";
      owner = config.services.patroni.user;
    };

    patroni-consul-token = {
      inherit (nodes.orpheus.config.age.secrets.patroni-consul-token) rekeyFile;
      owner = config.services.patroni.user;
    };
  }
  // genAttrs' dbUsers (user: {
    name = "${user}-postgres-password";
    value = {
      generator.script = "alnum";
      intermediary = true; # we don't keep these on the host
    };
  });

  services.patroni = {
    enable = true;
    scope = "homelab-cluster";
    name = config.node.name;
    postgresqlPackage = pkgs.postgresql_16;

    nodeIp = nebulaIp;

    otherNodesIps = [
      globals.nebula.mesh.hosts.orpheus.ipv4
    ];

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

        pg_hba = [
          "host replication replicator ${globals.nebula.mesh.cidrv4} scram-sha-256"
          "host all all ${globals.nebula.mesh.cidrv4} scram-sha-256"
        ];
      };

      tags = {
        failover_priority = "2";
      };
    };

    environmentFiles = {
      PATRONI_SUPERUSER_PASSWORD = config.age.secrets.patroni-superuser-password.path;
      PATRONI_REPLICATION_PASSWORD = config.age.secrets.patroni-replication-password.path;
      PATRONI_CONSUL_TOKEN = config.age.secrets.patroni-consul-token.path;
    };
  };

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
