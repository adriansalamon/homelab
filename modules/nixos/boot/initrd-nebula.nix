{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.boot.initrd.network.nebula;

  nebulaConfig = (pkgs.formats.yaml { }).generate "nebula-initrd.yml" {
    pki = {
      ca = "/etc/nebula-initrd/ca.crt";
      cert = "/etc/nebula-initrd/host.crt";
      key = "/etc/nebula-initrd/host.key";
    };
    static_host_map = cfg.staticHostMap;
    lighthouse = {
      am_lighthouse = false;
      hosts = cfg.lighthouses;
    };
    listen = {
      host = "0.0.0.0";
      port = 4242;
    };
    tun.dev = "nebula.initrd";
    punchy.punch = true;
    firewall = {
      inherit (cfg.firewall) inbound outbound;
    };
  };
in
{
  options.boot.initrd.network.nebula = {
    enable = mkEnableOption "Nebula VPN connectivity during early boot for remote disk unlock";

    ca = mkOption {
      type = types.path;
      description = ''
        Path to the Nebula CA certificate. This is a public file and can be a
        Nix store path (e.g. a file from the repo).
      '';
    };

    cert = mkOption {
      type = types.path;
      description = ''
        Path to the host certificate. This is a public file and can be a
        Nix store path.
      '';
    };

    key = mkOption {
      type = types.path;
      description = ''
        Path to the host private key. Must be a non-symlink static file on
        disk since it is embedded into the initrd cpio at build time.

        This will be readable unencrypted on the drive during boot. Don't
        give any groups/permissions.

        Use an agenix secret with `symlink = false` pointing to a path on
        /boot (the unencrypted ESP), e.g. /boot/initrd-nebula.key.
      '';
    };

    lighthouses = mkOption {
      type = types.listOf types.str;
      description = "List of Nebula lighthouse overlay IP addresses.";
      example = [ "10.64.32.1" ];
    };

    staticHostMap = mkOption {
      type = types.attrsOf (types.listOf types.str);
      description = "Static host map: lighthouse overlay IP → list of underlay addr:port.";
      example = {
        "10.64.32.1" = [ "1.2.3.4:4242" ];
      };
    };

    firewall = {
      inbound = mkOption {
        type = types.listOf types.attrs;
        default = [
          {
            port = "2222";
            proto = "tcp";
            group = "network-admin";
          }
          {
            port = "any";
            proto = "icmp";
            host = "any";
          }
        ];
        description = "Nebula firewall inbound rules for the initrd Nebula instance.";
      };

      outbound = mkOption {
        type = types.listOf types.attrs;
        default = [
          {
            port = "any";
            proto = "any";
            host = "any";
          }
        ];
        description = "Nebula firewall outbound rules for the initrd Nebula instance.";
      };
    };
  };

  config = mkIf (config.boot.initrd.network.enable && cfg.enable) {
    assertions = [
      {
        assertion = cfg.lighthouses != [ ];
        message = "boot.initrd.network.nebula.lighthouses must not be empty";
      }
    ];

    boot.initrd.availableKernelModules = [ "tun" ];

    # Embed all necessary files into the initrd cpio at build time.
    # ca and cert can be store paths; key must be a static file on disk.
    boot.initrd.secrets = {
      "/etc/nebula-initrd/ca.crt" = cfg.ca;
      "/etc/nebula-initrd/host.crt" = cfg.cert;
      "/etc/nebula-initrd/host.key" = cfg.key;
      "/etc/nebula-initrd/config.yml" = nebulaConfig;
    };

    # Non-systemd initrd support
    boot.initrd.extraUtilsCommands = mkIf (!config.boot.initrd.systemd.enable) ''
      copy_bin_and_libs ${pkgs.nebula}/bin/nebula
    '';

    boot.initrd.network.postCommands = mkIf (!config.boot.initrd.systemd.enable) ''
      nebula -config /etc/nebula-initrd/config.yml &
    '';

    # Systemd initrd support
    boot.initrd.systemd.storePaths = [ "${pkgs.nebula}/bin/nebula" ];

    boot.initrd.systemd.services.nebula-initrd = {
      wantedBy = [ "initrd.target" ];
      after = [
        "network.target"
        "initrd-nixos-copy-secrets.service"
      ];
      before = [ "sshd.service" ];
      serviceConfig = {
        ExecStart = "${pkgs.nebula}/bin/nebula -config /etc/nebula-initrd/config.yml";
        Type = "simple";
        Restart = "on-failure";
        RestartSec = "2s";
      };
    };
  };
}
