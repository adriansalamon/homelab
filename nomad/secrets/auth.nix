{
  inputs,
  globals,
  lib,
  ...
}:
let
  localSecretsDir = ./files;

  mkSecret = job: path: {
    rekeyFile = "${localSecretsDir}/${job}-${path}";
    nomadPath = "nomad/jobs/${job}";
  };

  mkOidcSecret = name: {
    name = "${name}-oidc-client-secret";
    value = {
      rekeyFile = localSecretsDir + "/oidc/${name}-oidc-client-secret.txt.age";
      nomadPath = "nomad/jobs/authelia";
      # this server is not supposed to have this file, upload the hash instead
      intermediary = true;
      hashFile = "${localSecretsDir}/oidc/${name}-oidc-client-hash.txt";
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

  # TODO: Maybe we store this in Consul kv and read in the job spec?
  oidcClients =
    lib.mapAttrs
      (
        name: cfg:
        cfg
        // {
          client_secret = lib.readFile "${localSecretsDir}/oidc/${name}-oidc-client-hash.txt";
          pre_configured_consent_duration = "3 months";
          public = false;
        }
      )
      {
        immich = {
          # https://immich.app/docs/administration/oauth/
          client_name = "Immich";
          client_id = "xcz7Bm8a5EC-fDtgd2WPFhX7raI0H2ZcQZww7PmmyRsa8cfvUuNQUz2HRtkNXflqooHwmHAe";
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
        };
        jellyfin = {
          # https://www.authelia.com/integration/openid-connect/jellyfin/
          client_name = "Jellyfin";
          client_id = "3GATim_TL9yrNLsWhrC9mv0L-44zmv44qDu1EH8ZoXZVdGDrLaQYjjRO49Y66AKGDfzmS6yt";
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
        };
        tailscale = {
          # https://www.authelia.com/integration/openid-connect/tailscale/
          client_name = "Tailscale";
          client_id = "M47wLZwSUPGuGEqeU172pz8eJ6zSPb1aDuZ-h0Y1z9JCEsb-eC27K6UzBuGLSCPF8Am-XpUF";
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
        };
        headscale = {
          # https://www.authelia.com/integration/openid-connect/clients/headscale/
          client_name = "Headscale";
          client_id = "headscale";
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
        };
        paperless = {
          client_name = "Paperless";
          client_id = "paperless";
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
        };
        grafana = {
          client_name = "Grafana";
          client_id = "grafana";
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
        };
        open-webui = {
          client_name = "Open WebUI";
          client_id = "open-webui";
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
        };
        forgejo = {
          # https://www.authelia.com/integration/openid-connect/clients/forgejo/
          client_name = "Forgejo";
          client_id = "forgejo";
          require_pkce = true;
          pkce_challenge_method = "S256";
          redirect_uris = [
            "https://forgejo.${globals.domains.main}/user/oauth2/authelia/callback"
          ];
          scopes = [
            "openid"
            "profile"
            "email"
            "groups"
          ];
          response_types = [ "code" ];
          grant_types = [ "authorization_code" ];
          access_token_signed_response_alg = "none";
          token_endpoint_auth_method = "client_secret_basic";
        };
        hass = {
          client_id = "hass";
          client_name = "Home Assistant";
          require_pkce = true;
          pkce_challenge_method = "S256";
          authorization_policy = "two_factor";
          redirect_uris = [
            "https://home-assistant.local.${globals.domains.main}/auth/oidc/callback"
          ];
          scopes = [
            "openid"
            "profile"
            "groups"
          ];
          id_token_signed_response_alg = "RS256";
          token_endpoint_auth_method = "client_secret_post";
        };
      };
in
{
  age.secrets = {
    lldap_jwt_secret = mkSecret "lldap" "jwt-secret.txt.age";
    lldap_key_seed = mkSecret "lldap" "key-seed.txt.age";
    lldap_user_password = mkSecret "lldap" "user-password.txt.age";
    lldap_postgres_password = {
      rekeyFile = inputs.self.outPath + "/secrets/generated/postgres/lldap-postgres-password.age";
      nomadPath = "nomad/jobs/lldap";
    };

    authelia_jwt_secret = mkSecret "authelia" "jwt-secret.txt.age";
    authelia_storage_encryption_key = mkSecret "authelia" "storage-encryption-key.txt.age";
    authelia_session_secret = mkSecret "authelia" "session-secret.txt.age";
    authelia_postgres_password = {
      rekeyFile = inputs.self.outPath + "/secrets/generated/postgres/authelia-postgres-password.age";
      nomadPath = "nomad/jobs/authelia";
    };
    authelia_redis_password = {
      rekeyFile = inputs.self.outPath + "/secrets/generated/valkey-server-password.age";
      nomadPath = "nomad/jobs/authelia";
    };
    authelia_redis_sentinel_password = {
      rekeyFile = inputs.self.outPath + "/secrets/generated/valkey-sentinel-password.age";
      nomadPath = "nomad/jobs/authelia";
    };
    authelia_smtp_password = mkSecret "authelia" "smtp-password.txt.age";
    authelia_ldap_password = mkSecret "authelia" "ldap-password.txt.age";
    authelia_hmac_secret = mkSecret "authelia" "hmac-secret.txt.age";
    authelia_jwks_key = mkSecret "authelia" "jwks-key.key.age";
  }
  // lib.genAttrs' (builtins.attrNames oidcClients) mkOidcSecret;
}
