{ inputs, ... }:
{
  age.secrets = {
    linkding-postgres-password = {
      rekeyFile = inputs.self.outPath + "/secrets/generated/postgres/linkding-postgres-password.age";
      generator.script = "alnum";
      nomadPath = "nomad/jobs/linkding";
    };
  };
}
