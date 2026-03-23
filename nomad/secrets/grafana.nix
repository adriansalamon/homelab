{
  config,
  inputs,
  nodes,
  ...
}:
let
  localSecretsDir = ./files;
  nomadPath = "nomad/jobs/grafana";
in
{

  globals.loki-secrets = [ config.age.secrets.grafana-loki-basic-auth-password ];

  age.secrets = {
    grafana-postgres-password = {
      rekeyFile = inputs.self.outPath + "/secrets/generated/postgres/grafana-postgres-password.age";
      inherit nomadPath;
      generator.script = "alnum";
    };
    grafana-secret-key = {
      inherit (nodes.zeus-grafana.config.age.secrets.grafana-secret-key) rekeyFile;
      inherit nomadPath;
    };
    grafana-loki-basic-auth-password = {
      rekeyFile = localSecretsDir + "/grafana-loki-basic-auth-password.age";
      inherit nomadPath;
    };
    grafana-oidc-client-secret = {
      rekeyFile = localSecretsDir + "/oidc/grafana-oidc-client-secret.txt.age";
      inherit nomadPath;
    };
  };
}
