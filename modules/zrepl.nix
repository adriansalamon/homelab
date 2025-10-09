{
  config,
  lib,
  globals,
  pkgs,
  ...
}:
let
  cfg = config.meta.zrepl;
  me = config.node.name;
in
{
  # interface
  options.meta.zrepl = {
    enable = lib.mkEnableOption "Replicate zfs datasets with zrepl + snapshots";

    target = lib.mkOption {
      type = lib.types.str;
      default = "hermes";
    };

    filesystems = lib.mkOption {
      type = lib.types.attrsOf lib.types.bool;
      default = { };
      description = "filesystems to replicate, in the form zrepl expects, eg. `tank/<";
    };
  };

  # implementation
  config = lib.mkIf cfg.enable {
    # open the firewall on backup target
    globals.nebula.mesh.hosts.${cfg.target}.firewall.inbound = [
      {
        port = "8888";
        proto = "tcp";
        host = me;
      }
    ];

    # register metrics in Consul
    consul.services."${me}-zrepl-metrics" = {
      port = 9811;
      tags = [ "prometheus.scrape=true" ];
    };

    # allow the prometheus scrape server to access
    globals.nebula.mesh.hosts.${me}.firewall.inbound = [
      {
        port = "9811";
        proto = "tcp";
        host = "zeus-prometheus";
      }
    ];

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
              listen = "${globals.nebula.mesh.hosts.${me}.ipv4}:9811";
              listen_freebind = true;
            }
          ];
        };

        jobs = [
          {
            name = "snapshots";
            type = "snap";
            filesystems = cfg.filesystems;

            snapshotting = {
              type = "periodic";
              prefix = "_zrepl";
              interval = "15m";
            };

            pruning.keep = [
              {
                type = "regex";
                negate = true;
                regex = "^_zrepl.*$";
              }
              {
                type = "last_n";
                regex = "^_zrepl.*$";
                count = 10;
              }
              {
                type = "grid";
                regex = "^_zrepl.*$";
                grid = "1x1h(keep=all) | 24x1h | 30x1d | 12x30d";
              }
            ];
          }
          {
            name = "backup-to-hermes";
            type = "push";
            connect = {
              type = "tcp";
              address = "${globals.nebula.mesh.hosts.${cfg.target}.ipv4}:8888";
            };

            inherit (cfg) filesystems;

            snapshotting = {
              type = "manual";
            };

            pruning.keep_sender = [
              # pruning is done in snapshot job
              {
                type = "regex";
                regex = ".*";
              }
            ];

            pruning.keep_receiver = [
              {
                type = "regex";
                negate = true;
                regex = "^_zrepl.*$";
              }
              {
                type = "grid";
                regex = "^_zrepl.*$";
                grid = "1x1h(keep=all) | 24x1h | 30x1d | 12x30d";
              }
            ];
          }
        ];
      };
    };

    # run backups every night
    systemd.services."zrepl-backup" = {
      description = "Triggers a zrepl replicate/backup job";
      after = [ "zrepl.service" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.zrepl}/bin/zrepl signal wakeup backup-to-hermes";
      };
    };

    systemd.timers."zrepl-backup" = {
      description = "zrepl backup";
      wantedBy = [ "timers.target" ];
      partOf = [ "zrepl-backup.service" ];
      timerConfig = {
        OnCalendar = "01:00";
        RandomizedDelaySec = "3h";
        Persistent = true;
      };
    };
  };
}
