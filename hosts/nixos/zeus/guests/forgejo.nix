{
  config,
  pkgs,
  lib,
  globals,
  nodes,
  nomadCfg,
  ...
}:
let
  nebulaIp = globals.nebula.mesh.hosts.${config.node.name}.ipv4;
  anubisPort = 3000;
in
{

  age.secrets.forgejo-mailer-password.rekeyFile =
    config.node.secretsDir + "/forgejo-mailer-password.age";

  age.secrets.forgejo-oidc-client-secret = {
    inherit (nomadCfg.config.age.secrets.authelia-forgejo-oidc-client-secret) rekeyFile;
    mode = "440";
    inherit (config.services.forgejo) group;
  };

  globals.databases.forgejo = {
    owner = "forgejo";
  };

  age.secrets.forgejo-postgres-password = {
    inherit (nodes.zeus.config.age.secrets.postgres-password) rekeyFile;
    mode = "440";
    inherit (config.services.forgejo) group;
  };

  globals.nebula.mesh.hosts.${config.node.name} = {
    groups = [ "postgres-client" ];

    firewall.inbound = [
      {
        port = anubisPort;
        proto = "tcp";
        group = "reverse-proxy";
      }
    ];
  };

  globals.monitoring.http.forgejo = {
    url = "https://forgejo.${globals.domains.main}/api/v1/version";
    network = "external";
    expectedBodyRegex = "version";
  };

  globals.monitoring.tcp.forgejo = {
    host = "forgejo.${globals.domains.main}";
    port = 2222;
    network = "external";
  };

  consul.services.forgejo-ssh = {
    port = 22;
    tags = [
      "traefik.external=true"
      "traefik.enable=true"
      "traefik.tcp.routers.forgejo-ssh.rule=HostSNI(`*`)"
      "traefik.tcp.routers.forgejo-ssh.entrypoints=forgejo-ssh"
    ];
  };

  consul.services.forgejo = {
    port = anubisPort;
    tags = [
      "traefik.external=true"
      "traefik.enable=true"
      "traefik.http.routers.forgejo.rule=Host(`forgejo.${globals.domains.main}`)"
      "traefik.http.routers.forgejo.entrypoints=websecure"
    ];
  };

  environment.persistence."/persist".directories = [
    {
      directory = config.services.forgejo.stateDir;
      inherit (config.services.forgejo) user group;
      mode = "0700";
    }
  ];

  users.groups.git = { };
  users.users.git = {
    isSystemUser = true;
    useDefaultShell = true;
    group = "git";
    home = config.services.forgejo.stateDir;
  };

  services.openssh = {
    authorizedKeysFiles = [
      "${config.services.forgejo.stateDir}/.ssh/authorized_keys"
      "/etc/ssh/authorized_keys.d/%u"
    ];
    # Recommended by forgejo: https://forgejo.org/docs/latest/admin/recommendations/#git-over-ssh
    settings.AcceptEnv = [ "GIT_PROTOCOL" ];
  };

  services.anubis = {
    instances.forgejo.settings = {
      TARGET = "unix://${config.services.forgejo.settings.server.HTTP_ADDR}";
      BIND = "${nebulaIp}:3000";
      BIND_NETWORK = "tcp";
    };
  };

  services.forgejo = {
    enable = true;
    database = {
      createDatabase = false;
      type = "postgres";
      host = globals.nebula.mesh.hosts.zeus.ipv4;
      port = 5432;
      name = "forgejo";
      user = "forgejo";
      passwordFile = config.age.secrets.forgejo-postgres-password.path;
    };
    lfs.enable = true;
    user = "git";
    group = "git";
    secrets = {
      mailer.PASSWD = config.age.secrets.forgejo-mailer-password.path;
    };

    dump = {
      enable = true;
      file = "forgejo-dump"; # restic takes care of versioning
    };

    settings = {
      DEFAULT.APP_NAME = "Salamon Forgejo";
      "ui.meta" = {
        AUTHOR = "Salamon";
        DESCRIPTION = "Self hosted git-forge for Salamon.";
      };

      server = {
        DOMAIN = "forgejo.${globals.domains.main}";
        PROTOCOL = "http+unix";
        HTTP_PORT = 3001;
        ROOT_URL = "https://forgejo.${globals.domains.main}";
        SSH_PORT = 2222;
        SSH_USER = "git";
        LANDING_PAGE = "explore";
      };

      service = {
        DISABLE_REGISTRATION = false;
        ALLOW_ONLY_INTERNAL_REGISTRATION = false;
        ALLOW_ONLY_EXTERNAL_REGISTRATION = true;
        SHOW_REGISTRATION_BUTTON = false;
        REGISTER_EMAIL_CONFIRM = false;
        ENABLE_INTERNAL_SIGNIN = false;
        ENABLE_NOTIFY_MAIL = true;
      };

      actions = {
        ENABLED = true;
        DEFAULT_ACTIONS_URL = "github";
      };

      mailer = {
        ENABLED = true;
        SMTP_ADDR = "email-smtp.eu-west-1.amazonaws.com";
        SMTP_PORT = 587;
        IS_TLS_ENABLED = true;
        FROM = "Forgejo <forgejo@${globals.domains.main}>";
        USER = "AKIAT3JCT56DJVEYMR66";
      };

      oauth2_client = {
        ACCOUNT_LINKING = "login";
        USERNAME = "nickname";
        ENABLE_AUTO_REGISTRATION = false;
        REGISTER_EMAIL_CONFIRM = false;
      };

      repository = {
        DEFAULT_PRIVATE = "private";
        ENABLE_PUSH_CREATE_USER = true;
        ENABLE_PUSH_CREATE_ORG = true;
      };

      other = {
        SHOW_FOOTER_VERSION = false;
        SHOW_FOOTER_TEMPLATE_LOAD_TIME = false;
        ENABLE_FEED = false;
      };
    };
  };

  systemd.services.forgejo = {
    preStart =
      let
        exe = lib.getExe config.services.forgejo.package;
        provider = "authelia";
        clientId = "forgejo";
        args = lib.escapeShellArgs (
          lib.concatLists [
            [
              "--name"
              provider
            ]
            [
              "--provider"
              "openidConnect"
            ]
            [
              "--key"
              clientId
            ]
            [
              "--auto-discover-url"
              "https://auth.${globals.domains.main}/.well-known/openid-configuration"
            ]
            [
              "--scopes"
              "openid"
            ]
            [
              "--scopes"
              "profile"
            ]
            [
              "--scopes"
              "email"
            ]
            [
              "--scopes"
              "groups"
            ]
            [
              "--group-claim-name"
              "groups"
            ]
            [
              "--admin-group"
              "admin"
            ]
            [ "--skip-local-2fa" ]
          ]
        );
      in
      lib.mkAfter ''
        provider_id=$(${exe} admin auth list | ${pkgs.gnugrep}/bin/grep -w '${provider}' | cut -f1)
        SECRET="$(< ${config.age.secrets.forgejo-oidc-client-secret.path})"
        if [[ -z "$provider_id" ]]; then
          ${exe} admin auth add-oauth ${args} --secret "$SECRET"
        else
          ${exe} admin auth update-oauth --id "$provider_id" ${args} --secret "$SECRET"
        fi
      '';
  };

  # Don't run the default dump timer, we handle it ourselves.
  systemd.timers.forgejo-dump.enable = false;

  # Run before the backup service.
  systemd.services.forgejo-dump = {
    requiredBy = [ "restic-backups-storage-box-cloud-backups.service" ];
    before = [ "restic-backups-storage-box-cloud-backups.service" ];
  };

  meta.backups.storageboxes."cloud-backups" = {
    subuser = "forgejo";
    paths = [
      config.services.forgejo.dump.backupDir
    ];
  };
}
