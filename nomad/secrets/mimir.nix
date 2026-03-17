{ ... }:
{
  age.secrets.mimir-s3-secret-key = {
    rekeyFile = ./files + "/seaweedfs-mimir-secret-key.age";
    nomadPath = "nomad/jobs/mimir";
  };
}
