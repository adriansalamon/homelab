{
  config,
  pkgs,
  lib,
  nodes,
  globals,
  profiles,
  ...
}:
let
  port = 8000;
in
{

  microvm.mem = 1024 * 3;
  microvm.vcpu = 4;

  imports = [
    profiles.storage-users
  ];

  users.users."paperless".extraGroups = [ "scanning" ];

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/paperless";
      user = "paperless";
      group = "paperless";
      mode = "0750";
    }
  ];

  # TODO: explicit backups
  age.secrets.paperless-admin-password = {
    generator.script = "alnum";
    mode = "440";
    group = "paperless";
  };

  age.secrets.paperless-oidc-client-secret = {
    inherit (nodes.zeus-auth.config.age.secrets.paperless-oidc-client-secret) rekeyFile;
    mode = "440";
    group = "paperless";
  };

  age.secrets.postgres-password = {
    generator.dependencies = [ nodes.zeus.config.age.secrets.postgres-password ];
    generator.script = lib.helpers.generateWithEnv "PAPERLESS_DBPASS";
    mode = "440";
    group = "paperless";
  };

  globals.nebula.mesh.hosts.zeus-paperless.groups = [ "nfs-client" ];

  fileSystems."/paperless" = {
    device = "${globals.nebula.mesh.hosts.hermes.ipv4}:/data/tank02/shared/scanning/paperless";
    fsType = "nfs";
    options = [
      "nfsvers=4"
      "x-systemd.automount"
      "noauto"
    ];
  };

  services.paperless = {
    enable = true;
    inherit port;
    address = "0.0.0.0";
    passwordFile = config.age.secrets.paperless-admin-password.path;
    consumptionDir = "/paperless/consume";
    mediaDir = "/paperless/media";

    settings = {
      PAPERLESS_URL = "https://paperless.local.${globals.domains.main}";
      PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect";

      PAPERLESS_SOCIALACCOUNT_PROVIDERS = builtins.toJSON {
        openid_connect = {
          OAUTH_PKCE_ENABLED = "True";
          APPS = [
            {
              provider_id = "authelia";
              name = "Authelia";
              client_id = "paperless";
              # secret will be added dynamically
              #secret = "";
              settings.server_url = "https://auth.${globals.domains.main}";
            }
          ];
        };
      };

      GRANIAN_WORKERS = 4; # maybe this helps?

      PAPERLESS_CONSUMER_RECURSIVE = true;
      PAPERLESS_FILENAME_FORMAT = "{{ owner_username }}/{{ created_year }}-{{ created_month }}-{{ created_day }}_{{ asn }}_{{ title }}";
      PAPERLESS_OCR_LANGUAGE = "swe+eng";
      PAPERLESS_CONSUMER_POLLING = 5;
      PAPERLESS_DISABLE_REGULAR_LOGIN = true;

      PAPERLESS_SOCIAL_ACCOUNT_DEFAULT_GROUPS = "salamon";

      PAPERLESS_DBHOST = "zeus.node.consul";
      PAPERLESS_DBENGINE = "postgresql";
      PAPERLESS_DBPORT = 5432;
      PAPERLESS_DBNAME = "paperless";
      PAPERLESS_DBUSER = "paperless";
    };

    environmentFile = config.age.secrets.postgres-password.path;
  };

  # Add secret to PAPERLESS_SOCIALACCOUNT_PROVIDERS
  systemd.services.paperless-web.script = lib.mkBefore ''
    oidcSecret=$(< ${config.age.secrets.paperless-oidc-client-secret.path})
    export PAPERLESS_SOCIALACCOUNT_PROVIDERS=$(
      ${pkgs.jq}/bin/jq <<< "$PAPERLESS_SOCIALACCOUNT_PROVIDERS" \
        --compact-output \
        --arg oidcSecret "$oidcSecret" '.openid_connect.APPS.[0].secret = $oidcSecret'
    )
  '';

  globals.monitoring.http.paperless = {
    url = "https://paperless.local.${globals.domains.main}/";
    expectedBodyRegex = "Paperless-ngx";
    network = "internal";
  };

  consul.services = {
    paperless = {
      inherit port;
      tags = [
        "traefik.enable=true"
        "traefik.http.routers.paperless.rule=Host(`paperless.local.${globals.domains.main}`)"
      ];
    };
  };

  globals.nebula.mesh.hosts.zeus-paperless.firewall.inbound = [
    {
      port = builtins.toString port;
      proto = "tcp";
      group = "reverse-proxy";
    }
  ];

  # we need posgres access
  globals.nebula.mesh.hosts.zeus.firewall.inbound = [
    {
      port = "5432";
      proto = "tcp";
      host = "zeus-paperless";
    }
  ];
}
