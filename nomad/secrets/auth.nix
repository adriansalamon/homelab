{
  inputs,
  lib,
  ...
}:
let
  localSecretsDir = ./files;

  mkSecret = job: path: {
    rekeyFile = localSecretsDir + "/${job}-${path}";
  };

  mkOidcSecret = name: {
    name = "${name}-oidc-client-secret";
    value = {
      rekeyFile = localSecretsDir + "/oidc/${name}-oidc-client-secret.txt.age";
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

in
{
  nomadJobs.lldap.secrets = {
    jwt-secret = mkSecret "lldap" "jwt-secret.txt.age";
    key-seed = mkSecret "lldap" "key-seed.txt.age";
    user-password = mkSecret "lldap" "user-password.txt.age";
    postgres-password = {
      rekeyFile = inputs.self.outPath + "/secrets/generated/postgres/lldap-postgres-password.age";
    };
  };

  nomadJobs.authelia.secrets = {
    jwt-secret = mkSecret "authelia" "jwt-secret.txt.age";
    storage-encryption-key = mkSecret "authelia" "storage-encryption-key.txt.age";
    session-secret = mkSecret "authelia" "session-secret.txt.age";
    postgres-password = {
      rekeyFile = inputs.self.outPath + "/secrets/generated/postgres/authelia-postgres-password.age";
    };
    redis-password = {
      rekeyFile = inputs.self.outPath + "/secrets/generated/valkey-server-password.age";
    };
    redis-sentinel-password = {
      rekeyFile = inputs.self.outPath + "/secrets/generated/valkey-sentinel-password.age";
    };
    smtp-password = mkSecret "authelia" "smtp-password.txt.age";
    ldap-password = mkSecret "authelia" "ldap-password.txt.age";
    hmac-secret = mkSecret "authelia" "hmac-secret.txt.age";
    jwks-key = mkSecret "authelia" "jwks-key.key.age";
  }
  // lib.genAttrs' [
    "immich"
    "jellyfin"
    "tailscale"
    "headscale"
    "paperless"
    "grafana"
    "open-webui"
    "forgejo"
    "hass"
    "nomad"
    "linkwarden"
    "memos"
    "stalwart"
    "affine"
    "opengist"
  ] mkOidcSecret;
}
