{ inputs, ... }:
let
  localSecretsDir = ./files;
in
{
  age.secrets = {
    linkwarden-nextauth-secret = {
      rekeyFile = localSecretsDir + "/linkwarden-nextauth-secret.age";
      nomadPath = "nomad/jobs/linkwarden";
      generator.script = "base64";
    };
    linkwarden-oidc-client-secret = {
      rekeyFile = localSecretsDir + "/oidc/linkwarden-oidc-client-secret.txt.age";
      nomadPath = "nomad/jobs/linkwarden";
    };
    linkwarden-s3-secret-key = {
      rekeyFile = localSecretsDir + "/seaweedfs-linkwarden-secret-key.age";
      nomadPath = "nomad/jobs/linkwarden";
    };
    linkwarden-postgres-password = {
      rekeyFile = inputs.self.outPath + "/secrets/generated/postgres/linkwarden-postgres-password.age";
      nomadPath = "nomad/jobs/linkwarden";
      generator.script = "alnum";
    };
  };
}
