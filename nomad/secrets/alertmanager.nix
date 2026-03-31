{ ... }:
let
  localSecretsDir = ./files;
in
{
  nomadJobs.alertmanager.secrets = {
    pushover-user-key = {
      rekeyFile = localSecretsDir + "/alertmanager-pushover-user-key.age";
    };

    pushover-app-key = {
      rekeyFile = localSecretsDir + "/alertmanager-pushover-app-key.age";
    };
  };
}
