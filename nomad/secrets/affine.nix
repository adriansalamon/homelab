{
  inputs,
  lib,
  ...
}:
let
  localSecretsDir = ./files;
  nomadPath = "nomad/jobs/affine";

in
{
  age.secrets = {
    affine-s3-secret-key = {
      rekeyFile = localSecretsDir + "/seaweedfs-affine-secret-key.age";
      inherit nomadPath;
    };
    affine-postgres-password = {
      rekeyFile = inputs.self.outPath + "/secrets/generated/postgres/affine-postgres-password.age";
      generator.script = "alnum";
      inherit nomadPath;
    };
    affine-private-key = {
      generator.script =
        { pkgs, ... }: "${lib.getExe pkgs.openssl} ecparam -name prime256v1 -genkey -noout";
      inherit nomadPath;
    };
    affine-oidc-client-secret = {
      rekeyFile = localSecretsDir + "/oidc/affine-oidc-client-secret.txt.age";
      inherit nomadPath;
    };
    affine-redis-password = {
      rekeyFile = inputs.self.outPath + "/secrets/generated/valkey-server-password.age";
      inherit nomadPath;
    };
  };
}
