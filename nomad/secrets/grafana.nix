{
  config,
  inputs,
  lib,
  ...
}:
let
  localSecretsDir = ./files;
in
{
  nomadJobs.grafana.secrets = {
    postgres-password = {
      rekeyFile = inputs.self.outPath + "/secrets/generated/postgres/grafana-postgres-password.age";
      generator.script = "alnum";
    };
    secret-key = {
      rekeyFile = localSecretsDir + "/grafana-secret-key.age";
    };
    loki-basic-auth-password = {
      rekeyFile = localSecretsDir + "/grafana-loki-basic-auth-password.age";
    };
    oidc-client-secret = {
      rekeyFile = localSecretsDir + "/oidc/grafana-oidc-client-secret.txt.age";
    };
  };

  globals.loki-secrets = lib.mkAfter [ config.age.secrets.grafana-loki-basic-auth-password ];
}
