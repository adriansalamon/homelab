{
  ...
}:
let
  localSecretsDir = ./files;

  mkSecret = job: path: {
    rekeyFile = "${localSecretsDir}/${job}-${path}";
    nomadPath = "nomad/jobs/${job}";
  };
in
{
  age.secrets = {
    homepage-consul-http-token = mkSecret "homepage" "consul-http-token.age";
    homepage-jellyfin-token = mkSecret "homepage" "jellyfin-token.age";
  };
}
