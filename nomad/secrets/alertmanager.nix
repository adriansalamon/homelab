{ inputs, ... }:
let
  localSecretsDir = ./files;
in
{
  age.secrets = {
    alertmanager-pushover-user-key = {
      rekeyFile = localSecretsDir + "/pushover-alertmanager-user-key.age";
      nomadPath = "nomad/jobs/alertmanager";
    };
    alertmanager-pushover-app-key = {
      rekeyFile = inputs.self.outPath + "/pushover-alertmanager-app-key.age";
      nomadPath = "nomad/jobs/alertmanager";
    };
  };
}
