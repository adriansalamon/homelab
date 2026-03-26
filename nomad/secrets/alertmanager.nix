{ ... }:
let
  localSecretsDir = ./files;
in
{
  age.secrets = {
    alertmanager-pushover-user-key = {
      rekeyFile = localSecretsDir + "/alertmanager-pushover-user-key.age";
      nomadPath = "nomad/jobs/alertmanager";
    };
    alertmanager-pushover-app-key = {
      rekeyFile = localSecretsDir + "/alertmanager-pushover-app-key.age";
      nomadPath = "nomad/jobs/alertmanager";
    };
  };
}
