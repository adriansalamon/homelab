{
  inputs,
  lib,
  ...
}:
let
  localSecretsDir = ./files;

in
{
  nomadJobs.affine.secrets = {
    s3-secret-key = {
      rekeyFile = localSecretsDir + "/seaweedfs-affine-secret-key.age";
    };
    postgres-password = {
      rekeyFile = inputs.self.outPath + "/secrets/generated/postgres/affine-postgres-password.age";
      generator.script = "alnum";
    };
    private-key = {
      generator.script =
        { pkgs, ... }: "${lib.getExe pkgs.openssl} ecparam -name prime256v1 -genkey -noout";
    };
    oidc-client-secret = {
      rekeyFile = localSecretsDir + "/oidc/affine-oidc-client-secret.txt.age";
    };
    redis-password = {
      rekeyFile = inputs.self.outPath + "/secrets/generated/valkey-server-password.age";
    };
  };
}
