{
  config,
  lib,
  globals,
  ...
}:
let
  host = config.node.name;
  satadom = "ata-SuperMicro_SSD_SMC0515D90717A894641";
  ssd1 = "ata-SAMSUNG_MZ7LH480HAHQ-00005_S45PNE0M306774";
  ssd2 = "ata-SAMSUNG_MZ7LM480HMHQ-00005_S2UJNX0J404189";
in
{
  imports = [ ./disk-config.secret.nix ];

  boot.zfs.extraPools = [ "tank02" ];

  disko.devices = {
    disk = {
      satadom = {
        type = "disk";
        device = "/dev/disk/by-id/${satadom}";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
          };
        };
      };
      ssd1 = {
        type = "disk";
        device = "/dev/disk/by-id/${ssd1}";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zroot";
              };
            };
          };
        };
      };
      ssd2 = {
        type = "disk";
        device = "/dev/disk/by-id/${ssd2}";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zroot";
              };
            };
          };
        };
      };
    };
    zpool = {
      zroot = lib.disk.zfs.mkZpool {
        mode = "mirror";
        datasets = lib.disk.zfs.impermanenceDatasets;
      };

      tank02 = {
        type = "zpool";
        mountpoint = null;

        # Datasets defined in `disk-config.secret.nix`.
      };
    };
  };

  # We are a zfs replication sink
  services.zrepl = {
    enable = true;
    settings = {
      global = {
        logging = [
          {
            type = "stdout";
            level = "info";
            format = "human";
          }
        ];

        monitoring = [
          {
            type = "prometheus";
            listen = "${globals.nebula.mesh.hosts.${host}.ipv4}:9811";
            listen_freebind = true;
          }
        ];
      };

      jobs = [
        {
          name = "sink";
          type = "sink";
          serve = {
            type = "tcp";
            listen = "${globals.nebula.mesh.hosts.${host}.ipv4}:8888";
            listen_freebind = true;
            clients = lib.flip lib.mapAttrs' globals.nebula.mesh.hosts (
              name: hostCfg: {
                name = hostCfg.ipv4;
                value = name;
              }
            );
          };

          recv.placeholder.encryption = "off";

          root_fs = "tank02/backups";
        }
      ];
    };
  };

  # Backup to Hezner
  meta.backups.storageboxes."cloud-backups" = {
    subuser = "hermes-files";
    paths = [
      "/data/tank02/homes"
      "/data/tank02/shared"
    ];
  };

  # register metrics in Consul
  consul.services."zrepl" = {
    port = 9811;
    tags = [ "prometheus.scrape=true" ];
  };

  globals.nebula.mesh.hosts.${host}.firewall.inbound = [
    # allow senders to connect
    {
      port = "8888";
      proto = "tcp";
      group = "zrepl-sender";
    }
    # allow the prometheus scrape server to access
    {
      port = "9811";
      proto = "tcp";
      host = "zeus-prometheus";
    }
  ];
}
