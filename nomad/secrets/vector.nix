{
  config,
  lib,
  ...
}:
{
  nomadJobs.vector.secrets = {
    loki-basic-auth-password = {
      generator = {
        tags = [ "loki-basic-auth" ];
        script = "alnum";
      };
    };
  };

  globals.loki-secrets = lib.mkAfter [ config.age.secrets.vector-loki-basic-auth-password ];
}
