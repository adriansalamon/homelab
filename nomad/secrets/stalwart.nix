{ inputs, nodes, ... }:
let
  localSecretsDir = ./files;
in
{
  nomadJobs.stalwart.secrets = {
    s3-secret-key = {
      rekeyFile = localSecretsDir + "/seaweedfs-stalwart-secret-key.age";
    };
    postgres-password = {
      rekeyFile = inputs.self.outPath + "/secrets/generated/postgres/stalwart-postgres-password.age";
      generator.script = "alnum";
    };
    admin-password = {
      rekeyFile = localSecretsDir + "/stalwart-admin-password.age";
      generator.script = "alnum";
    };
    cloudflare-dns-api-token = {
      inherit (nodes.athena.config.age.secrets.cloudflare-dns-api-token) rekeyFile;
    };
  };
}
