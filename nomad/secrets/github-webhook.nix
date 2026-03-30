{ ... }:
let
  localSecretsDir = ./files;

  mkSecret = path: {
    rekeyFile = "${localSecretsDir}/github-${path}";
    nomadPath = "nomad/jobs/github-webhook";
  };
in
{
  age.secrets = {
    github-webhook-secret = mkSecret "webhook-secret.age";
    github-pat = mkSecret "pat.age";
    github-nomad-token = mkSecret "nomad-token.age";
  };
}
