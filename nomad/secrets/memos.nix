{ inputs, ... }:
{
  age.secrets = {
    memos-postgres-password = {
      rekeyFile = inputs.self.outPath + "/secrets/generated/postgres/memos-postgres-password.age";
      nomadPath = "nomad/jobs/memos";
    };
  };
}
