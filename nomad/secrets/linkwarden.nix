{ inputs, ... }:
let
  localSecretsDir = ./files;
in
{
  nomadJobs.linkwarden.secrets = {
    nextauth-secret = {
      rekeyFile = localSecretsDir + "/linkwarden-nextauth-secret.age";
      generator.script = "base64";
    };
    oidc-client-secret = {
      rekeyFile = localSecretsDir + "/oidc/linkwarden-oidc-client-secret.txt.age";
    };
    s3-secret-key = {
      rekeyFile = localSecretsDir + "/seaweedfs-linkwarden-secret-key.age";
    };
    postgres-password = {
      rekeyFile = inputs.self.outPath + "/secrets/generated/postgres/linkwarden-postgres-password.age";
      generator.script = "alnum";
    };
  };
}
