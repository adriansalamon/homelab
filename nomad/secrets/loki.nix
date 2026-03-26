{ globals, ... }:
{
  age.secrets.loki-s3-secret-key = {
    rekeyFile = ./files + "/seaweedfs-loki-secret-key.age";
    nomadPath = "nomad/jobs/loki";
  };

  age.secrets.loki-basic-auth-hashes = {
    generator.dependencies = globals.loki-secrets;
    # Using actual hashes here, while safer, proved very slow for many small requests, like ingesting logs. We could try
    # bcrypt with fewer rounds also, but that's not really necessary.
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
    nomadPath = "nomad/jobs/loki";
  };
}
