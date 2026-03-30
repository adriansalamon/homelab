{ lib, globals, ... }:
{
  mkNebula =
    cfg:
    let
      firewall = {
        outbound = [
          {
            port = "any";
            proto = "any";
            host = "any";
          }
        ]
        ++ (cfg.firewall.outbound or [ ]);

        inbound = (cfg.firewall.inbound or [ ]);
      };
    in
    {
      nebula_roles = builtins.toJSON cfg.groups;
      nebula_config = builtins.toJSON { inherit firewall; };
    };

  nebula.acceptGroups =
    {
      port,
      groups ? [
        "reverse-proxy"
        "nomad-client"
      ],
    }:
    map (group: {
      inherit port;
      proto = "tcp";
      group = group;
    }) groups;

  # Helper for standard postgres DSN secret template
  postgresEnv =
    {
      dbName,
      dbUser,
      dbHost ? "master.homelab-cluster.service.consul",
      dbPort ? 5432,
      envVar,
    }:
    {
      data = ''
        {{ with nomadVar "nomad/jobs/${dbName}" }}
        ${envVar}="postgresql://${dbUser}:{{ .postgres_password }}@${dbHost}:${toString dbPort}/${dbName}?sslmode=disable"
        {{ end }}
      '';
      destination = "\${NOMAD_SECRETS_DIR}/postgres.env";
      env = true;
      perms = "0600";
    };

  # Service definition helper
  mkService =
    {
      name,
      port,
      tags ? [ ],
      checks ? [ ],
      addressMode ? "alloc",
    }:
    {
      inherit
        name
        addressMode
        tags
        checks
        ;
      port = toString port;
    };

  # TCP health check helper
  mkTcpCheck =
    {
      port,
      interval ? 30 * lib.time.second,
      timeout ? 10 * lib.time.second,
    }:
    {
      addressMode = "alloc";
      port = toString port;
      type = "tcp";
      inherit interval timeout;
    };

  # HTTP health check helper
  mkHttpCheck =
    {
      port,
      path ? "/",
      interval ? 30 * lib.time.second,
      timeout ? 10 * lib.time.second,
      addressMode ? "alloc",
    }:
    {
      port = toString port;
      type = "http";
      inherit
        path
        interval
        timeout
        addressMode
        ;
    };

  # Alias for consistency with mk* naming convention
  mkTraefikTags =
    {
      name,
      external ? false,
      entrypoint ? "websecure",
      rule ? null,
    }:
    [
      "traefik.enable=true"
    ]
    ++ lib.optionals external [
      "traefik.external=true"
    ]
    ++ [
      "traefik.http.routers.${name}.rule=${
        if rule != null then rule else "Host(`${name}.${globals.domains.main}`)"
      }"
      "traefik.http.routers.${name}.entrypoints=${entrypoint}"
    ];

}
