{
  config,
  lib,
  inputs,
  nodes,
  ...
}:
let
  localSecretsDir = ./files;

  # Helper for SeaweedFS S3 secret keys
  mkWeedSecret =
    clientName:
    let
      name = "${clientName}-secret-key";
    in
    {
      inherit name;
      value = {
        rekeyFile = localSecretsDir + "/seaweedfs-${name}.age";
        generator.script = "alnum";
      };
    };
in
{
  # Affine
  nomadJobs.affine.secrets = {
    s3-secret-key = {
      inherit (config.nomadJobs.seaweedfs-filer.secrets.affine-secret-key) rekeyFile;
    };
    postgres-password = {
      rekeyFile = inputs.self.outPath + "/secrets/generated/postgres/affine-postgres-password.age";
      generator.script = "alnum";
    };
    private-key = {
      generator.script =
        { pkgs, ... }: "${lib.getExe pkgs.openssl} ecparam -name prime256v1 -genkey -noout";
    };
    oidc-client-secret = {
      inherit (config.nomadJobs.authelia.secrets.affine-oidc-client-secret) rekeyFile;
    };
    redis-password = {
      rekeyFile = inputs.self.outPath + "/secrets/generated/valkey-server-password.age";
    };
  };

  # Renovate
  nomadJobs.renovate.secrets = {
    forgejo-token.rekeyFile = localSecretsDir + "/renovate-forgejo-token.age";
    github-token.rekeyFile = localSecretsDir + "/renovate-github-token.age";
  };

  # Linkding
  nomadJobs.linkding.secrets = {
    postgres-password = {
      rekeyFile = inputs.self.outPath + "/secrets/generated/postgres/linkding-postgres-password.age";
      generator.script = "alnum";
    };
  };

  # Memos
  nomadJobs.memos.secrets = {
    postgres-password.rekeyFile =
      inputs.self.outPath + "/secrets/generated/postgres/memos-postgres-password.age";
  };

  # Opengist
  nomadJobs.opengist.secrets = {
    oidc-client-secret = {
      inherit (config.nomadJobs.authelia.secrets.opengist-oidc-client-secret) rekeyFile;
    };
    postgres-password = {
      rekeyFile = inputs.self.outPath + "/secrets/generated/postgres/opengist-postgres-password.age";
      generator.script = "alnum";
    };
  };

  # SeaweedFS Filer
  nomadJobs.seaweedfs-filer.secrets =
    builtins.listToAttrs (
      map mkWeedSecret [
        "admin"
        "memos"
        "stalwart"
        "loki"
        "affine"
      ]
    )
    // {
      postgres-password = {
        rekeyFile = inputs.self.outPath + "/secrets/generated/postgres/seaweedfs-postgres-password.age";
      };
    };

  # Stalwart
  nomadJobs.stalwart.secrets = {
    s3-secret-key = {
      inherit (config.nomadJobs.seaweedfs-filer.secrets.stalwart-secret-key) rekeyFile;
    };
    postgres-password = {
      rekeyFile = inputs.self.outPath + "/secrets/generated/postgres/stalwart-postgres-password.age";
      generator.script = "alnum";
    };
    admin-password = {
      rekeyFile = localSecretsDir + "/stalwart-admin-password.age";
      generator.script = "alnum";
    };
    ldap-password = {
      rekeyFile = localSecretsDir + "/stalwart-ldap-password.age";
    };
    cloudflare-dns-api-token = {
      inherit (nodes.athena.config.age.secrets.cloudflare-dns-api-token) rekeyFile;
    };
  };
}
