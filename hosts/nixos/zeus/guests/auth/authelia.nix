{
  config,
  lib,
  nodes,
  globals,
  ...
}:
let
  port = 9091;

  mkSecret = name: {
    rekeyFile = ./secrets/${name};
    owner = "authelia-default";
  };

  mkOidcSecrets = name: {
    "${name}-oidc-client-secret" = {
      rekeyFile = ./secrets/oidc/${name}-oidc-client-secret.txt.age;
      # this server is not supposed to have this file
      intermediary = true;
      generator.script =
        { pkgs, file, ... }:
        ''
          # Generate an rfc3986 secret
          secret=$(${pkgs.openssl}/bin/openssl rand -base64 54 | tr -d '\n' | tr '+/' '-_' | tr -d '=' | cut -c1-72)

          # Generate a pbkdf2 hash, and store in plaintext file
          hashed=$(echo $secret | ${pkgs.python3}/bin/python3 -c "
          import hashlib, base64, os, sys
          input = sys.stdin.readlines()[0].strip()
          base64_adapted_alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789./'
          def encode_base64_adapted(data):
              base64_encoded = base64.b64encode(data).decode('utf-8').strip('=')
              return base64_encoded.translate(str.maketrans('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/', base64_adapted_alphabet))
          salt = os.urandom(16)
          key = hashlib.pbkdf2_hmac('sha512', input.encode(), salt, 310000, 64)
          salt_b64 = encode_base64_adapted(salt)
          key_b64 = encode_base64_adapted(key)
          print(f'\$pbkdf2-sha512\''${310000}\''${salt_b64}\''${key_b64}')")

          echo "$hashed" > ${lib.escapeShellArg (lib.removeSuffix "-secret.txt.age" file + "-hash.txt")}
          echo "$secret"
        '';
    };
  };
in
{

  # Only log files here
  environment.persistence."/state".directories = [
    {
      directory = "/var/lib/authelia-default";
      user = "authelia-default";
      group = "authelia-default";
      mode = "0700";
    }
  ];

  age.generators.rfc3986 =
    { pkgs, ... }:
    "${pkgs.openssl}/bin/openssl rand -base64 54 | tr -d '\n' | tr '+/' '-_' | tr -d '=' | cut -c1-72";

  services.authelia.instances.default = {
    enable = true;
    secrets = with config.age.secrets; {
      storageEncryptionKeyFile = authelia-storage-encryption-key.path;
      sessionSecretFile = authelia-session-secret.path;
      jwtSecretFile = authelia-jwt-secret.path;
      oidcIssuerPrivateKeyFile = jwks-key.path;
      oidcHmacSecretFile = hmac-secret.path;
    };

    settings = {
      log.level = "info";
      log.file_path = "/var/lib/authelia-default/log.txt";

      webauthn = {
        enable_passkey_login = true;
      };

      access_control = {
        default_policy = "deny";
        rules = lib.mkAfter [
          {
            domain = "*.${globals.domains.main}";
            policy = "two_factor";
          }
        ];
      };

      storage.postgres = {
        address = "${globals.nebula.mesh.hosts.zeus.ipv4}:5432";
        database = "authelia";
        username = "authelia";
      };

      session = {
        name = "authelia_session";
        cookies = [
          {
            domain = "${globals.domains.main}";
            authelia_url = "https://auth.${globals.domains.main}";
          }
        ];

        redis = {
          host = globals.nebula.mesh.hosts.zeus.ipv4;
          port = 6379;
        };
      };

      identity_providers.oidc = {
        authorization_policies.default = {
          default_policy = "two_factor";
          rules = [
            {
              policy = "deny";
              subject = "group:lldap_strict_readonly";
            }
          ];
        };

        # TODO: more DRY could be done here
        clients = [
          {
            # https://immich.app/docs/administration/oauth/
            client_name = "Immich";
            client_id = "xcz7Bm8a5EC-fDtgd2WPFhX7raI0H2ZcQZww7PmmyRsa8cfvUuNQUz2HRtkNXflqooHwmHAe";
            client_secret = lib.readFile ./secrets/oidc/immich-oidc-client-hash.txt;
            public = false;
            pre_configured_consent_duration = "1 month";
            redirect_uris = [
              "app.immich:///oauth-callback"
              "https://immich.${globals.domains.main}/auth/login"
              "https://immich.${globals.domains.main}/user-settings"
            ];
            scopes = [
              "openid"
              "profile"
              "email"
            ];
            token_endpoint_auth_method = "client_secret_post";
            userinfo_signed_response_alg = "none";
          }
          {
            # https://www.authelia.com/integration/openid-connect/jellyfin/
            client_name = "Jellyfin";
            client_id = "3GATim_TL9yrNLsWhrC9mv0L-44zmv44qDu1EH8ZoXZVdGDrLaQYjjRO49Y66AKGDfzmS6yt";
            client_secret = lib.readFile ./secrets/oidc/jellyfin-oidc-client-hash.txt;
            pre_configured_consent_duration = "1 month";
            public = false;
            require_pkce = true;
            pkce_challenge_method = "S256";
            redirect_uris = [
              "https://jellyfin.${globals.domains.main}/sso/OID/redirect/authelia"
            ];
            scopes = [
              "openid"
              "profile"
              "email"
              "groups"
            ];
            userinfo_signed_response_alg = "none";
            token_endpoint_auth_method = "client_secret_post";
          }
          {
            # https://www.authelia.com/integration/openid-connect/tailscale/
            client_name = "Tailscale";
            client_id = "M47wLZwSUPGuGEqeU172pz8eJ6zSPb1aDuZ-h0Y1z9JCEsb-eC27K6UzBuGLSCPF8Am-XpUF";
            client_secret = lib.readFile ./secrets/oidc/tailscale-oidc-client-hash.txt;
            pre_configured_consent_duration = "1 month";
            redirect_uris = [
              "https://login.tailscale.com/a/oauth_response"
            ];
            scopes = [
              "openid"
              "email"
              "profile"
            ];
            userinfo_signed_response_alg = "none";
            token_endpoint_auth_method = "client_secret_basic";
          }
          {
            # https://www.authelia.com/integration/openid-connect/clients/headscale/
            client_name = "Headscale";
            client_id = "headscale";
            client_secret = lib.readFile ./secrets/oidc/headscale-oidc-client-hash.txt;
            pre_configured_consent_duration = "1 month";
            redirect_uris = [
              "https://headscale.${globals.domains.main}/oidc/callback"
            ];
            scopes = [
              "openid"
              "email"
              "profile"
              "groups"
            ];
            userinfo_signed_response_alg = "none";
            token_endpoint_auth_method = "client_secret_post";
          }
          {
            client_name = "Paperless";
            client_id = "paperless";
            client_secret = lib.readFile ./secrets/oidc/paperless-oidc-client-hash.txt;
            pre_configured_consent_duration = "1 month";
            redirect_uris = [
              "https://paperless.local.${globals.domains.main}/accounts/oidc/authelia/login/callback/"
            ];
            scopes = [
              "openid"
              "groups"
              "email"
              "profile"
            ];
            userinfo_signed_response_alg = "none";
          }
          {
            client_name = "Grafana";
            client_id = "grafana";
            client_secret = lib.readFile ./secrets/oidc/grafana-oidc-client-hash.txt;
            pre_configured_consent_duration = "1 month";
            redirect_uris = [
              "https://grafana.local.${globals.domains.main}/login/generic_oauth"
            ];
            scopes = [
              "openid"
              "groups"
              "email"
              "profile"
            ];
            userinfo_signed_response_alg = "none";
          }
          {
            client_name = "Firezone";
            client_id = "firezone";
            client_secret = lib.readFile ./secrets/oidc/firezone-oidc-client-hash.txt;
            pre_configured_consent_duration = "1 month";
            redirect_uris = [
              "https://firezone.${globals.domains.main}/9debab95-2caa-4220-83de-a6a95a0bc825/sign_in/providers/1cb03132-27f1-4e28-95a3-135d798c7c10/handle_callback"
              "https://firezone.${globals.domains.main}/9debab95-2caa-4220-83de-a6a95a0bc825/settings/identity_providers/openid_connect/1cb03132-27f1-4e28-95a3-135d798c7c10/handle_callback"
            ];
            scopes = [
              "openid"
              "email"
              "profile"
            ];
            token_endpoint_auth_method = "client_secret_post";
          }
          {
            client_name = "Open WebUI";
            client_id = "open-webui";
            client_secret = lib.readFile ./secrets/oidc/open-webui-oidc-client-hash.txt;
            pre_configured_consent_duration = "1 month";
            require_pkce = false;
            pkce_challenge_method = "";
            redirect_uris = [
              "https://chat.${globals.domains.main}/oauth/oidc/callback"
            ];
            scopes = [
              "openid"
              "profile"
              "groups"
              "email"
            ];
            response_types = [
              "code"
            ];
            grant_types = [
              "authorization_code"
            ];
            access_token_signed_response_alg = "none";
            userinfo_signed_response_alg = "none";
            token_endpoint_auth_method = "client_secret_basic";
          }

        ];
      };

      authentication_backend.ldap = {
        address = "ldap://localhost:3890";
        base_dn = "dc=salamon,dc=xyz";
        implementation = "lldap";
        user = "uid=authelia,ou=people,dc=salamon,dc=xyz";
      };

      notifier.disable_startup_check = true;
      notifier.smtp = {
        address = "smtp://email-smtp.eu-west-1.amazonaws.com:587";
        sender = "Authelia <authelia@${globals.domains.main}>";
        username = builtins.readFile ./secrets/authelia-smtp-username.txt;
        timeout = "5s";
      };
    };

    environmentVariables = with config.age.secrets; {
      AUTHELIA_STORAGE_POSTGRES_PASSWORD_FILE = postgres-password.path;
      AUTHELIA_SESSION_REDIS_PASSWORD_FILE = redis-password.path;
      AUTHELIA_NOTIFIER_SMTP_PASSWORD_FILE = smtp-password.path;
      AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PASSWORD_FILE = ldap-password.path;
    };
  };

  age.secrets = lib.mkMerge [
    {
      authelia-jwt-secret = mkSecret "authelia-jwt-secret.txt.age";
      authelia-storage-encryption-key = mkSecret "authelia-storage-encryption-key.txt.age";
      authelia-session-secret = mkSecret "authelia-session-secret.txt.age";
      postgres-password = {
        inherit (nodes.zeus.config.age.secrets.postgres-password) rekeyFile;
        owner = "authelia-default";
      };
      redis-password = {
        inherit (nodes.zeus.config.age.secrets.redis-password) rekeyFile;
        owner = "authelia-default";
      };
      smtp-password = mkSecret "authelia-smtp-password.txt.age";
      ldap-password = mkSecret "authelia-ldap-password.txt.age";
      hmac-secret = mkSecret "authelia-hmac-secret.txt.age";
      jwks-key = mkSecret "authelia-jwks-key.key.age";
    }
    (mkOidcSecrets "immich")
    (mkOidcSecrets "jellyfin")
    (mkOidcSecrets "tailscale")
    (mkOidcSecrets "headscale")
    (mkOidcSecrets "paperless")
    (mkOidcSecrets "grafana")
    (mkOidcSecrets "firezone")
    (mkOidcSecrets "open-webui")
  ];

  globals.monitoring.http.authelia = {
    url = "https://auth.${globals.domains.main}/api/health";
    network = "external";
    expectedBodyRegex = "OK";
  };

  consul.services.authelia = {
    inherit port;
    tags = [
      "traefik.enable=true"
      "traefik.external=true"
      "traefik.http.routers.authelia.rule=Host(`auth.${globals.domains.main}`)"
      "traefik.http.routers.authelia.entrypoints=websecure"
      "traefik.http.middlewares.authelia.forwardAuth.address=http://${globals.nebula.mesh.hosts.zeus-auth.ipv4}:${toString port}/api/authz/forward-auth"
      "traefik.http.middlewares.authelia.forwardAuth.trustForwardHeader=true"
      "traefik.http.middlewares.authelia.forwardAuth.authResponseHeaders=Remote-User,Remote-Groups,Remote-Name,Remote-Email"
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
