{ inputs, ... }:
let
  localSecretsDir = ./files;
in
{
  age.secrets = {
    seaweedfs-admin-secret-key = {
      rekeyFile = localSecretsDir + "/seaweedfs-admin-secret-key.age";
      nomadPath = "nomad/jobs/seaweedfs-filer";
      generator.script = "alnum";
    };
    swaweedfs-linkwarden-secret-key = {
      rekeyFile = localSecretsDir + "/seaweedfs-linkwarden-secret-key.age";
      nomadPath = "nomad/jobs/seaweedfs-filer";
      generator.script = "alnum";
    };
    swaweedfs-postgres-password = {
      rekeyFile = inputs.self.outPath + "/secrets/generated/postgres/seaweedfs-postgres-password.age";
      nomadPath = "nomad/jobs/seaweedfs-filer";
    };
  };
}
