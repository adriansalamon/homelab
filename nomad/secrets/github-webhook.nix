{ ... }:
let
  localSecretsDir = ./files;

  mkSecret = path: {
    rekeyFile = localSecretsDir + "/github-${path}";
  };
in
{
  nomadJobs.github-webhook.secrets = {
    webhook-secret = mkSecret "webhook-secret.age";
    pat = mkSecret "pat.age";
    nomad-token = mkSecret "nomad-token.age";
  };
}
