{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.seaweedfs;

  replicationModule = replication: {
    options = {
      dataCenter = mkOption {
        type = types.ints.between 0 9;
        default = 0;
      };

      rack = mkOption {
        type = types.ints.between 0 9;
        default = 1;
      };

      server = mkOption {
        type = types.ints.between 0 9;
        default = 0;
      };

      code = mkOption {
        readOnly = true;
        internal = true;
        type = types.str;
        default = with replication.config; "${toString dataCenter}${toString rack}${toString server}";
      };
    };
  };

  ipPortModule = {
    options = {
      ip = mkOption {
        type = types.str;
        description = "IP address or hostname";
      };

      port = mkOption {
        type = types.port;
        description = "Port number";
      };
    };
  };

  formatPeer = peer: "${peer.ip}:${toString peer.port}";

in
{
  options.services.seaweedfs = {
    enable = mkEnableOption "SeaweedFS distributed storage";

    package = mkOption {
      type = types.package;
      default = pkgs.seaweedfs;
      description = "SeaweedFS package to use";
    };

    # Master server configuration
    master = {
      enable = mkEnableOption "SeaweedFS master server";

      ip = mkOption {
        type = types.str;
        default = config.networking.hostName;
        description = "IP address to advertise";
      };

      port = mkOption {
        type = types.port;
        default = 9333;
        description = "Master server port";
      };

      peers = mkOption {
        type = with types; listOf (submodule ipPortModule);
        default = [ ];
        description = "List of all master servers in the cluster";
        example = [
          {
            ip = "master-a.local";
            port = 9333;
          }
          {
            ip = "master-b.local";
            port = 9333;
          }
          {
            ip = "master-c.local";
            port = 9333;
          }
        ];
      };

      defaultReplication = mkOption {
        type = types.submodule replicationModule;
        default = { };
        description = "Default replication strategy (010 = 2 copies in different racks)";
      };

      volumeSizeLimitMB = mkOption {
        type = types.ints.unsigned;
        default = 30000;
        description = "Master stops directing writes to oversized volumes";
      };

      dataDir = mkOption {
        type = types.str;
        default = "/var/lib/seaweedfs/master";
        description = "Directory for master metadata";
      };
    };

    # Volume server configuration
    volume = {
      enable = mkEnableOption "SeaweedFS volume server";

      ip = mkOption {
        type = types.str;
        default = config.networking.hostName;
        description = "IP address to advertise";
      };

      port = mkOption {
        type = types.port;
        default = 8080;
        description = "Volume server port";
      };

      dataCenter = mkOption {
        type = types.str;
        default = "";
        description = "Data center name (e.g., siteA, siteB)";
        example = "siteA";
      };

      rack = mkOption {
        type = types.str;
        default = "";
        description = "Rack name";
        example = "rack1";
      };

      dataDirs = mkOption {
        type = with types; listOf str;
        default = [ "/var/lib/seaweedfs/volume" ];
        description = "Directories to store volume data";
        example = [
          "/mnt/storage1"
          "/mnt/storage2"
        ];
      };

      maxVolumes = mkOption {
        type = types.ints.unsigned;
        default = 8;
        description = "Maximum number of volumes";
      };

      masters = mkOption {
        type = with types; listOf (submodule ipPortModule);
        default = [ ];
        description = "List of master servers";
        example = [
          {
            ip = "master-a.local";
            port = 9333;
          }
          {
            ip = "master-b.local";
            port = 9333;
          }
          {
            ip = "master-c.local";
            port = 9333;
          }
        ];
      };

      fileSizeLimitMB = mkOption {
        type = types.ints.unsigned;
        default = 256;
        description = "Limit file size to store per file";
      };

      minFreeSpacePercent = mkOption {
        type = types.ints.unsigned;
        default = 1;
        description = "Minimum free disk space percentage";
      };

      publicUrl = mkOption {
        type = types.str;
        default = "";
        description = "Public URL for volume server access";
        example = "http://volume.example.com:8080";
      };

    };
  };

  config = mkIf cfg.enable (mkMerge [
    # Master server service
    (mkIf cfg.master.enable {
      systemd.services.seaweedfs-master = {
        description = "SeaweedFS Master Server";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];

        preStart = ''
          mkdir -p ${cfg.master.dataDir}
        '';

        serviceConfig = {
          Type = "simple";
          User = "seaweedfs";
          Group = "seaweedfs";
          ExecStart = ''
            ${cfg.package}/bin/weed master \
              -ip=${cfg.master.ip} \
              -port=${toString cfg.master.port} \
              -mdir=${cfg.master.dataDir} \
              -defaultReplication=${cfg.master.defaultReplication.code} \
              -volumeSizeLimitMB=${toString cfg.master.volumeSizeLimitMB} \
              ${optionalString (cfg.master.peers != [ ]) ''
                -peers=${concatMapStringsSep "," formatPeer cfg.master.peers} \
                -raftHashicorp
              ''}
          '';
          Restart = "on-failure";
          RestartSec = "5s";

          # Security hardening
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ReadWritePaths = [ cfg.master.dataDir ];
        };
      };
    })

    # Volume server service
    (mkIf cfg.volume.enable {
      systemd.services.seaweedfs-volume = {
        description = "SeaweedFS Volume Server";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];

        preStart = ''
          ${concatMapStringsSep "\n" (dir: "mkdir -p ${dir}") cfg.volume.dataDirs}
        '';

        serviceConfig = {
          Type = "simple";
          User = "seaweedfs";
          Group = "seaweedfs";
          ExecStart = ''
            ${cfg.package}/bin/weed volume \
              -ip=${cfg.volume.ip} \
              -port=${toString cfg.volume.port} \
              -dir=${concatStringsSep "," cfg.volume.dataDirs} \
              -max=${toString cfg.volume.maxVolumes} \
              -mserver=${concatMapStringsSep "," formatPeer cfg.volume.masters} \
              -fileSizeLimitMB=${toString cfg.volume.fileSizeLimitMB} \
              -minFreeSpacePercent=${toString cfg.volume.minFreeSpacePercent} \
              ${optionalString (cfg.volume.dataCenter != "") "-dataCenter=${cfg.volume.dataCenter}"} \
              ${optionalString (cfg.volume.rack != "") "-rack=${cfg.volume.rack}"} \
              ${optionalString (cfg.volume.publicUrl != "") "-publicUrl=${cfg.volume.publicUrl}"}
          '';
          Restart = "on-failure";
          RestartSec = "5s";

          # Security hardening
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ReadWritePaths = cfg.volume.dataDirs;
        };
      };
    })

    {
      users.users.seaweedfs = {
        isSystemUser = true;
        group = "seaweedfs";
        description = "SeaweedFS system user";
      };
      users.groups.seaweedfs = { };
    }
  ]);
}
