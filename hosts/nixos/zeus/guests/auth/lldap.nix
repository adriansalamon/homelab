{
  config,
  lib,
  nodes,
  globals,
  ...
}:
let
  localSecretsDir = ./secrets;
  port = 17170;
in
{
  # TODO: It would be nice provision the users and groups declaratively :)

  users = {
    users.lldap = {
      group = "lldap";
      isSystemUser = true;
    };
    groups.lldap = { };
  };

  services.lldap = {
    enable = true;
    settings = {
      ldap_base_dn = "dc=salamon,dc=xyz";
      ldap_user_email = "admin@${globals.domains.alt}";
      http_url = "https://lldap.local.${globals.domains.main}";
      force_ldap_user_pass_reset = "always";
    };
    environment = {
      LLDAP_JWT_SECRET_FILE = config.age.secrets.jwt-secret.path;
      LLDAP_LDAP_USER_PASS_FILE = config.age.secrets.user-password.path;
      LLDAP_KEY_SEED_FILE = config.age.secrets.key-seed.path;
    };
  };

  systemd.services.lldap = {
    script = lib.mkBefore ''
      export LLDAP_DATABASE_URL=postgres://lldap:$(cat ${config.age.secrets.lldap-postgres-password.path})@zeus.node.consul:5432/lldap
    '';

    # In case it fails to start, we should restart and see if we can
    # connect to the database
    serviceConfig = {
      Restart = "always";
      RestartSec = 5;
    };
  };

  age.secrets = {
    jwt-secret = {
      rekeyFile = localSecretsDir + "/ldap-jwt-secret.txt.age";
      owner = "lldap";
    };
    key-seed = {
      rekeyFile = localSecretsDir + "/ldap-key-seed.txt.age";
      owner = "lldap";
    };
    user-password = {
      rekeyFile = localSecretsDir + "/ldap-user-password.txt.age";
      owner = "lldap";
    };
    lldap-postgres-password = {
      inherit (nodes.zeus.config.age.secrets.postgres-password) rekeyFile;
      owner = "lldap";
    };
  };

  consul.services.lldap = {
    inherit port;
    tags = [
      "traefik.enable=true"
      "traefik.http.routers.lldap.rule=Host(`lldap.local.${globals.domains.main}`)"
    ];
  };

  globals.nebula.mesh.hosts.zeus-auth.firewall.inbound = [
    {
      port = builtins.toString port;
      proto = "tcp";
      group = "reverse-proxy";
    }
  ];
}
