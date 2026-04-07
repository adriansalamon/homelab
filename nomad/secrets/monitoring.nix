{
  config,
  inputs,
  globals,
  lib,
  ...
}:
let
  localSecretsDir = ./files;
in
{
  # Alertmanager
  nomadJobs.alertmanager.secrets = {
    pushover-user-key = {
      rekeyFile = localSecretsDir + "/alertmanager-pushover-user-key.age";
    };

    pushover-app-key = {
      rekeyFile = localSecretsDir + "/alertmanager-pushover-app-key.age";
    };
  };

  # Grafana
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
      inherit (config.nomadJobs.authelia.secrets.grafana-oidc-client-secret) rekeyFile;
    };
  };

  # Loki
  nomadJobs.loki.secrets = {
    s3-secret-key = {
      inherit (config.nomadJobs.seaweedfs-filer.secrets.loki-secret-key) rekeyFile;
    };

    basic-auth-hashes = {
      generator.dependencies = globals.loki-secrets;
      generator = {
        tags = [ "loki-basic-auth-json" ];
        script =
          {
            lib,
            decrypt,
            deps,
            ...
          }:
          lib.concatMapStrings (
            {
              name,
              host,
              file,
            }:
            let
              formatName = name: (builtins.replaceStrings [ ":" ] [ "/" ] (lib.escapeShellArg name));
            in
            ''
              echo "${formatName host}"+"${formatName name}:{PLAIN}$(${decrypt} ${lib.escapeShellArg file})" \
                || die "Failure while aggregating basic auth hashes"
            ''
          ) deps;
      };
    };
  };

  # Vector
  nomadJobs.vector.secrets = {
    loki-basic-auth-password = {
      generator = {
        tags = [ "loki-basic-auth" ];
        script = "alnum";
      };
    };
  };

  # Register Loki basic auth secrets
  globals.loki-secrets = lib.mkAfter [
    config.age.secrets.grafana-loki-basic-auth-password
    config.age.secrets.vector-loki-basic-auth-password
  ];
}
