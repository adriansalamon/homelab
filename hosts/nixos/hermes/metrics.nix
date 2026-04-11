{
  inputs,
  config,
  lib,
  globals,
  pkgs,
  ...
}:
let
  inherit (lib)
    flip
    mapAttrsToList
    concatMapAttrs
    ;

  host = config.node.name;

  # Monitor local backups
  # Remote Hetzner backups are monitored by the Nomad rustic-exporter job
  localBackups = {
    "adrian-hermes" = {
      repository = "/data/tank02/backups/restic-adrian/repo";
      secretKey = "adrian-hermes";
    };
    "christian-hermes" = {
      repository = "/data/tank02/backups/restic-christian/repo";
      secretKey = "christian-hermes";
    };
  };

  # Helper to create rustic backup config for local repos
  mkRusticBackup = name: backupCfg: {
    inherit name;
    inherit (backupCfg) repository;
    password_file = config.age.secrets."${backupCfg.secretKey}-repo-key".path;
    options = { };
  };
in
{
  environment.systemPackages = [
    pkgs.rustic-exporter
  ];

  age.secrets = flip concatMapAttrs localBackups (
    name: backupCfg: {
      "${backupCfg.secretKey}-repo-key" = {
        rekeyFile = inputs.self.outPath + "/secrets/restic/${backupCfg.secretKey}-encryption-key.age";
      };
    }
  );

  services.prometheus.exporters.rustic = {
    enable = true;
    port = 6780;
    host = globals.nebula.mesh.hosts.${host}.ipv4;

    # Need root to read local backup repos
    user = "root";

    settings = {
      backup = flip mapAttrsToList localBackups mkRusticBackup;
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
      group = "metrics-collector";
    }
  ];
}
