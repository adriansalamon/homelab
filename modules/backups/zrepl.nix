{
  config,
  lib,
  globals,
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

    # register metrics in Consul
    consul.services."zrepl" = {
      port = 9811;
      tags = [ "prometheus.scrape=true" ];
    };

    globals.nebula.mesh.hosts.${me} = {
      # add to nebula group to allow access to hermes
      groups = [ "zrepl-sender" ];

      # allow the prometheus scrape server to access
      firewall.inbound = [
        {
          port = "9811";
          proto = "tcp";
          host = "zeus-prometheus";
        }
      ];
    };

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
            name = "backup-to-hermes";
            type = "push";
            connect = {
              type = "tcp";
              address = "${globals.nebula.mesh.hosts.${cfg.target}.ipv4}:8888";
            };
            inherit (cfg) filesystems;

            snapshotting = {
              type = "periodic";
              prefix = "_zrepl";
              interval = "30m";
            };

            pruning.keep_sender = [
              {
                type = "regex";
                negate = true;
                regex = "^_zrepl.*$";
              }
              {
                type = "grid";
                regex = "^_zrepl.*$";
                grid = "1x1h(keep=all) | 24x1h | 14x1d";
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
  };
}
