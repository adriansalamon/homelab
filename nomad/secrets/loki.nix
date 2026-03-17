{ ... }:
{
  age.secrets.loki-s3-secret-key = {
    rekeyFile = ./files + "/seaweedfs-loki-secret-key.age";
    nomadPath = "nomad/jobs/loki";
  };
}
