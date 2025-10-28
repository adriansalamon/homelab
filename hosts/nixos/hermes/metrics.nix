{
  inputs,
  config,
  lib,
  nodes,
  globals,
  pkgs,
  ...
}:
let
  inherit (lib)
    flip
    mapAttrsToList
    attrValues
    concatMapAttrs
    filterAttrs
    flatten
    ;

  host = config.node.name;

  allBackupCfgs = flip filterAttrs nodes (
    name: hostCfg: hostCfg.config.meta.backups.storageboxes != { }
  );

  # Backups not defined in other nix flakes
  manualBackups = {
    "adrian-hermes" = {
      repository = "/data/tank02/backups/restic-adrian/repo";
      secretKey = "adrian-hermes";
    };
    "christian-hermes" = {
      repository = "/data/tank02/backups/restic-christian/repo";
      secretKey = "christian-hermes";
    };
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

  mkSftpOptions =
    boxCfg:
    let
      box = globals.hetzner.storageboxes.${boxCfg.name};
    in
    {
      endpoint = "ssh://${box.mainUser}.your-storagebox.de:23";
      user = box.mainUser;
      key = config.age.secrets."hetzner-main-repo-key".path;
      root = "/home/${box.users.${boxCfg.subuser}.path}/repo/";
    };

  mkRusticBackup = name: backupCfg: {
    inherit name;
    inherit (backupCfg) repository;
    password_file = config.age.secrets."${backupCfg.secretKey}-repo-key".path;
    options = if backupCfg.repository == "opendal:sftp" then mkSftpOptions backupCfg else { };
  };
in
{
  environment.systemPackages = [
    pkgs.rustic-exporter
  ];

  age.secrets = {
    "hetzner-main-repo-key" = {
      generator.script = "ssh-ed25519";
    };
  }
  # manual backup secrets
  // flip concatMapAttrs manualBackups (
    name: backupCfg: {
      "${backupCfg.secretKey}-repo-key" = {
        rekeyFile = inputs.self.outPath + "/secrets/restic/${backupCfg.secretKey}-encryption-key.age";
      };
    }
  )
  # From all nix config backups
  // flip concatMapAttrs allBackupCfgs (
    node: hostCfg: {
      "restic-metrics-${node}-repo-key" = {
        inherit (hostCfg.config.age.secrets.restic-encryption-password) rekeyFile;
      };
    }
  );

  services.prometheus.exporters.rustic = {
    enable = true;
    port = 6780;
    host = globals.nebula.mesh.hosts.${host}.ipv4;

    # A) We need to monitor local backups so need to read all user files?
    # B) We also need to be root because known hosts only (?) applies to root
    user = "root";

    settings = {
      backup =
        # Manual backups
        flip mapAttrsToList manualBackups mkRusticBackup
        # automatically discover storage targets from all nodes
        ++ flatten (
          flip mapAttrsToList allBackupCfgs (
            node: hostCfg:
            flip map (attrValues hostCfg.config.meta.backups.storageboxes) (boxCfg: {
              name = "${node}-${boxCfg.name}-${boxCfg.subuser}";
              repository = "opendal:sftp";
              password_file = config.age.secrets."restic-metrics-${node}-repo-key".path;
              options = mkSftpOptions boxCfg;
            })
          )
        );
    };
  };

  # register metrics in Consul
  consul.services."rustic" = {
    inherit (config.services.prometheus.exporters.rustic) port;
    tags = [ "prometheus.scrape=true" ];
  };

  # allow the prometheus scrape server to access
  globals.nebula.mesh.hosts.${host}.firewall.inbound = [
    {
      port = toString config.services.prometheus.exporters.rustic.port;
      proto = "tcp";
      host = "zeus-prometheus";
    }
  ];
}
