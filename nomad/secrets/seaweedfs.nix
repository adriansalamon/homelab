{ inputs, ... }:
let
  localSecretsDir = ./files;

  mkWeedSecret =
    clienName:
    let
      name = "${clienName}-secret-key";
    in
    {
      inherit name;
      value = {
        rekeyFile = localSecretsDir + "/seaweedfs-${name}.age";
        generator.script = "alnum";
      };
    };

  secrets = map mkWeedSecret [
    "admin"
    "memos"
    "stalwart"
    "loki"
    "affine"
  ];
in
{
  nomadJobs.seaweedfs-filer.secrets = builtins.listToAttrs secrets // {
    postgres-password = {
      rekeyFile = inputs.self.outPath + "/secrets/generated/postgres/seaweedfs-postgres-password.age";
    };
  };
}
