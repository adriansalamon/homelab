{ inputs, ... }:
{
  nomadJobs.linkding.secrets = {
    postgres-password = {
      rekeyFile = inputs.self.outPath + "/secrets/generated/postgres/linkding-postgres-password.age";
      generator.script = "alnum";
    };
  };
}
