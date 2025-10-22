{
  pkgs,
  config,
  lib,
  globals,
  ...
}:
{

  # TODO: We should probably have different passwords for each service
  age.secrets.postgres-password = {
    generator.script = "alnum";
    owner = "postgres";
  };

  services.postgresql = {
    enable = true;
    enableTCPIP = true;

    authentication = ''
      local   all             postgres                                trust
      host    all             all       ${globals.nebula.mesh.cidrv4} scram-sha-256
    '';
    ensureDatabases = [
      "authelia"
      "lldap"
      "paperless"
      "forgejo"
    ];

    ensureUsers = [
      {
        name = "authelia";
        ensureDBOwnership = true;
      }
      {
        name = "lldap";
        ensureDBOwnership = true;
      }
      {
        name = "paperless";
        ensureDBOwnership = true;
      }
      {
        name = "forgejo";
        ensureDBOwnership = true;
      }
    ];
  };

  systemd.services.postgresql.serviceConfig.ExecStartPost =
    let
      password_file_path = config.age.secrets.postgres-password.path;
      PSQL = "${lib.getExe' config.services.postgresql.package "psql"}";
      sqlFile = pkgs.writeText "postgres-password.sql" ''
        DO $$
        DECLARE password TEXT;
        BEGIN
          password := trim(both from replace(pg_read_file('${password_file_path}'), E'\n', '''));
          EXECUTE format('ALTER ROLE authelia WITH PASSWORD '''%s''';', password);
          EXECUTE format('ALTER ROLE lldap WITH PASSWORD '''%s''';', password);
          EXECUTE format('ALTER ROLE paperless WITH PASSWORD '''%s''';', password);
          EXECUTE format('ALTER ROLE forgejo WITH PASSWORD '''%s''';', password);
        END $$;
      '';
    in
    "${PSQL} -f ${sqlFile}";

  consul.services.postgres = {
    inherit (config.services.postgresql) port;
  };

  globals.nebula.mesh.hosts.${config.node.name}.firewall.inbound = [
    {
      port = builtins.toString config.services.postgresql.settings.port;
      proto = "tcp";
      group = "postgres-client";
    }
  ];
}
