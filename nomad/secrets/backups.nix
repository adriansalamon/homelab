{
  config,
  lib,
  nodes,
  inputs,
  ...
}:
let
  inherit (lib)
    flip
    concatMapAttrs
    filterAttrs
    ;

  nodeBackupConfigs = flip filterAttrs nodes (
    _name: hostCfg: hostCfg.config.meta.backups.storageboxes != { }
  );

  manualBackups = {
    "adrian-cloud-backups" = {
      repository = "opendal:sftp";
      secretKey = "adrian-hetzner";
      name = "cloud-backups"; # box config name
      subuser = "adrian";
    };
    "christian-cloud-backups" = {
      repository = "opendal:sftp";
      secretKey = "christian-hetzner";
      name = "cloud-backups";
      subuser = "christian";
    };
  };
in
{
  backups = {
    vault.subuser = "vault-snapshots";
    postgres.subuser = "postgres-dumps";
    seaweedfs.subuser = "seaweedfs-s3";
    nomad-volumes.subuser = "nomad-volumes";
  };

  nomadJobs.backup-seaweedfs.secrets.s3-secret-key = {
    inherit (config.nomadJobs.seaweedfs-filer.secrets.admin-secret-key) rekeyFile;
  };

  nomadJobs.rustic-exporter.secrets = {
    "ssh-private-key" = {
      generator.script = "ssh-ed25519";
    };
  }
  // flip concatMapAttrs manualBackups (
    _name: backupCfg: {
      "${backupCfg.secretKey}-repo-key" = {
        rekeyFile = inputs.self.outPath + "/secrets/restic/${backupCfg.secretKey}-encryption-key.age";
      };
    }
  )
  # From all nix host config backups
  // flip concatMapAttrs nodeBackupConfigs (
    node: hostCfg: {
      "${node}-repo-key" = {
        inherit (hostCfg.config.age.secrets.restic-encryption-password) rekeyFile;
      };
    }
  )
  # From all nomad backups defined above
  // flip concatMapAttrs config.backups (
    name: _cfg: {
      "${name}-repo-key" = {
        inherit (config.nomadJobs."backup-${name}".secrets.restic-password) rekeyFile;
      };
    }
  );
}
