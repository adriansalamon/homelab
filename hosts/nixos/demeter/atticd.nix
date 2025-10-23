{ config, globals, ... }:
let
  user = config.services.atticd.user;
  port = 8004;
  host = "nix-cache.local.${globals.domains.main}";
in
{
  age.secrets.atticEnv = {
    # contains:
    # - ATTIC_SERVER_TOKEN_HS256_SECRET_BASE64
    rekeyFile = config.node.secretsDir + "/atticd.env.age";
  };

  services.postgresql = {
    enable = true;
    ensureUsers = [
      {
        name = user;
        ensureDBOwnership = true;
      }
    ];
    ensureDatabases = [ user ];
  };

  services.atticd = {
    enable = true;
    mode = "monolithic";
    environmentFile = config.age.secrets.atticEnv.path;

    settings = {
      listen = "${globals.nebula.mesh.hosts.${config.node.name}.ipv4}:${builtins.toString port}";
      allowed-hosts = [ host ];
      api-endpoint = "https://${host}/";
      storage = {
        type = "local";
        path = "/data/tank01/cache";
      };

      jwt = { };

      database.url = "postgresql:///${user}";

      compression = {
        type = "zstd";
      };

      chunking = {
        nar-size-threshold = 64 * 1024; # chunk files that are 64 KiB or larger
        min-size = 16 * 1024; # 16 KiB
        avg-size = 64 * 1024; # 64 KiB
        max-size = 256 * 1024; # 256 KiB
      };

      garbage-collection = {
        interval = "12 hours";
        default-retention-period = "3 months";
      };
    };
  };

  systemd.services.atticd.after = [
    "postgresql.service"
    "nss-lookup.target"
  ];

  consul.services.atticd = {
    inherit port;
    tags = [
      "traefik.enable=true"
      "traefik.http.routers.atticd.rule=Host(`${host}`)"
      "traefik.http.routers.atticd.entrypoints=websecure"
    ];
  };

  globals.nebula.mesh.hosts.${config.node.name}.firewall.inbound = [
    {
      "port" = builtins.toString port;
      "proto" = "tcp";
      "group" = "reverse-proxy";
    }
  ];
}
