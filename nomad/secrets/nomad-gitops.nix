{ ... }:
let
  localSecretsDir = ./files;
in
{
  age.secrets = {
    nomadgitops-consul-token = {
      rekeyFile = localSecretsDir + "/nomad-gitops-consul-token.age";
      nomadPath = "nomad/jobs/nomad-gitops";
    };
    nomadgitops-nomad-token = {
      rekeyFile = localSecretsDir + "/nomad-gitops-nomad-token.age";
      nomadPath = "nomad/jobs/nomad-gitops";
    };
  };
}
