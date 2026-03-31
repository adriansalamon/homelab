{ inputs, ... }:
let
  localSecretsDir = ./files;

in
{
  nomadJobs.opengist.secrets = {
    postgres-password = {
      rekeyFile = inputs.self.outPath + "/secrets/generated/postgres/opengist-postgres-password.age";
      generator.script = "alnum";
    };
    oidc-client-secret = {
      rekeyFile = localSecretsDir + "/oidc/opengist-oidc-client-secret.txt.age";
    };
  };
}
