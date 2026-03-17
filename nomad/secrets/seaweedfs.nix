{ inputs, ... }:
let
  localSecretsDir = ./files;
  nomadPath = "nomad/jobs/seaweedfs-filer";

  mkWeedSecret =
    clienName:
    let
      name = "seaweedfs-${clienName}-secret-key";
    in
    {
      inherit name;
      value = {
        rekeyFile = localSecretsDir + "/${name}.age";
        inherit nomadPath;
        generator.script = "alnum";
      };
    };

  secrets = map mkWeedSecret [
    "admin"
    "linkwarden"
    "memos"
    "stalwart"
    "mimir"
    "loki"
  ];
in
{
  age.secrets = builtins.listToAttrs secrets // {
    swaweedfs-postgres-password = {
      rekeyFile = inputs.self.outPath + "/secrets/generated/postgres/seaweedfs-postgres-password.age";
      nomadPath = "nomad/jobs/seaweedfs-filer";
    };
  };
}
