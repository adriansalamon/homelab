{ inputs, nodes, ... }:
let
  localSecretsDir = ./files;
in
{
  age.secrets = {
    stalwart-s3-secret-key = {
      rekeyFile = localSecretsDir + "/seaweedfs-stalwart-secret-key.age";
      nomadPath = "nomad/jobs/stalwart";
    };
    stalwart-postgres-password = {
      rekeyFile = inputs.self.outPath + "/secrets/generated/postgres/stalwart-postgres-password.age";
      nomadPath = "nomad/jobs/stalwart";
      generator.script = "alnum";
    };
    stalwart-admin-password = {
      rekeyFile = localSecretsDir + "/stalwart-admin-password.age";
      nomadPath = "nomad/jobs/stalwart";
      generator.script = "alnum";
    };
    stalwart-cloudflare-dns-api-token = {
      inherit (nodes.athena.config.age.secrets.cloudflare-dns-api-token) rekeyFile;
      nomadPath = "nomad/jobs/stalwart";
    };
  };
}
