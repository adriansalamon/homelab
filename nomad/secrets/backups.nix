{ config, ... }:
{
  imports = [
    ../../modules/backups/nomad-backups.nix
  ];

  backups = {
    vault = {
      subuser = "vault-snapshots";
    };

    postgres = {
      subuser = "postgres-dumps";
    };

    seaweedfs = {
      subuser = "seaweedfs-s3";
    };

    nomad-volumes = {
      subuser = "nomad-volumes";
    };
  };

  nomadJobs.backup-seaweedfs.secrets.s3-secret-key = {
    inherit (config.nomadJobs.seaweedfs-filer.secrets.admin-secret-key) rekeyFile;
  };
}
