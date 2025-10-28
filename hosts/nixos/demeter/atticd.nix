{
  config,
  globals,
  lib,
  ...
}:
let
  port = 8004;
  host = "nix-cache.local.${globals.domains.main}";
in
{
  age.secrets.atticEnv = {
    # contains:
    # - ATTIC_SERVER_TOKEN_HS256_SECRET_BASE64
    rekeyFile = config.node.secretsDir + "/atticd.env.age";
  };

  # This is annoying :(
  age.secrets.atticFullEnv.generator = {
    dependencies = { inherit (config.age.secrets) atticEnv atticd-postgres-password; };
    script =
      {
        lib,
        decrypt,
        deps,
        ...
      }:
      ''
        passwd=$(${decrypt} ${lib.escapeShellArg deps.atticd-postgres-password.file})
        ${decrypt} ${lib.escapeShellArg deps.atticEnv.file}
        echo "ATTIC_SERVER_DATABASE_URL='postgresql://atticd:"$passwd"@primary.homelab-cluster.service.consul:5432/atticd'"
      '';
  };

  globals.databases.atticd = {
    owner = "atticd";
  };

  services.atticd = {
    enable = true;
    mode = "monolithic";
    environmentFile = config.age.secrets.atticFullEnv.path;

    settings = {
      listen = "${globals.nebula.mesh.hosts.${config.node.name}.ipv4}:${builtins.toString port}";
      allowed-hosts = [ host ];
      api-endpoint = "https://${host}/";
      storage = {
        type = "local";
        path = "/data/tank01/cache";
      };

      jwt = { };

      compression = {
        type = "zstd";
      };

      database = lib.mkForce { };

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
