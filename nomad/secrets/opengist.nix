{ inputs, ... }:
let
  localSecretsDir = ./files;
  nomadPath = "nomad/jobs/opengist";

in
{
  age.secrets = {
    opengist-postgres-password = {
      rekeyFile = inputs.self.outPath + "/secrets/generated/postgres/opengist-postgres-password.age";
      generator.script = "alnum";
      inherit nomadPath;
    };
    opengist-oidc-client-secret = {
      rekeyFile = localSecretsDir + "/oidc/opengist-oidc-client-secret.txt.age";
      inherit nomadPath;
    };
  };
}
