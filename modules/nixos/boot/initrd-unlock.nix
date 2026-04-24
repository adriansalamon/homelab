# NixOS module for remote ZFS unlock via SSH in initrd.
{
  config,
  globals,
  nodes,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.boot.initrd.remoteUnlock;
  meshCfg = globals.nebula.mesh;

  lighthouses = lib.filterAttrs (_: v: v.lighthouse) meshCfg.hosts;
  externalAddrs = name: [ "${nodes.${name}.config.node.publicIp}:4242" ];
  hostMeshCfg = meshCfg.hosts.${config.networking.hostName};

  notifyScript = pkgs.writeShellScript "notify-unlock" ''
    out=$(ip -4 route get 1.1.1.1 2>/dev/null); ip=''${out#*src }; ip=''${ip%% *}
    until ${pkgs.curl}/bin/curl -s --fail \
      --cacert ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt \
      --form-string "token=$(cat /boot/pushover-initrd-app)" \
      --form-string "user=$(cat /boot/pushover-initrd-user)" \
      --form-string "title=${config.networking.hostName}: ZFS Unlock Required" \
      --form-string "message=DHCP: $ip${lib.optionalString cfg.nebula "\nNebula: ${hostMeshCfg.ipv4}"}${"\n"}SSH port 2222" \
      https://api.pushover.net/1/messages.json
    do
      sleep 10
    done
  '';
in
{
  options.boot.initrd.remoteUnlock = {
    enable = lib.mkEnableOption "remote ZFS unlock via SSH on port 2222 in initrd";

    nebula = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Bring up Nebula in initrd and restrict SSH to the overlay IP.
        Requires globals.nebula.mesh.hosts.<name>.initrd.enable = true to
        generate the initrd cert.

        Set to false for hosts that are themselves the Nebula lighthouse —
        their Nebula is not running during initrd, so SSH listens on 0.0.0.0
        and is reachable on the public IP.
      '';
    };

    notify = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Send a Pushover notification when waiting for ZFS unlock";
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable initrd cert generation in the Nebula mesh config
    globals.nebula.mesh.hosts.${config.networking.hostName}.initrd.enable = cfg.nebula;

    boot.initrd.network.enable = true;
    boot.zfs.requestEncryptionCredentials = true;

    boot.initrd.network.nebula = lib.mkIf cfg.nebula {
      enable = true;
      ca = inputs.self.outPath + "/secrets/nebula/mesh/ca_combined.crt";
      cert = lib.removeSuffix ".key.age" config.age.secrets."nebula-mesh-initrd.key".rekeyFile + ".crt";
      key = config.age.secrets."nebula-mesh-initrd.key".path;
      lighthouses = lib.mapAttrsToList (_: lhCfg: lhCfg.ipv4) lighthouses;
      staticHostMap = lib.mapAttrs' (
        name: lhCfg: lib.nameValuePair lhCfg.ipv4 (externalAddrs name)
      ) lighthouses;
    };

    boot.initrd.network.ssh = {
      enable = true;
      port = 2222;
      hostKeys = [ "/boot/initrd-ssh-host-key" ];
      authorizedKeys = globals.admin-user.pubkeys;
      # Restrict to Nebula overlay IP when using nebula.
      # Otherwise listen on all interfaces (reachable on public IP).
      extraConfig = lib.optionalString cfg.nebula "ListenAddress ${hostMeshCfg.ipv4}";
    };

    # Pushover notification: curl loop until API call succeeds, then exits.
    boot.initrd.systemd.storePaths = lib.mkIf cfg.notify [
      pkgs.curl
      pkgs.cacert
      notifyScript
    ];

    boot.initrd.systemd.services.notify-unlock = lib.mkIf cfg.notify {
      wantedBy = [ "initrd.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = notifyScript;
      };
    };

    # Credentials are decrypted to /boot at activation, then embedded into the
    # initrd cpio at build time via boot.initrd.secrets. Two-deploy rule applies:
    # first deploy writes the files to /boot, second deploy embeds them.
    age.secrets."pushover-initrd-app" = lib.mkIf cfg.notify {
      rekeyFile = inputs.self.outPath + "/secrets/pushover/initrd-app-key.age";
      symlink = false;
      path = "/boot/pushover-initrd-app";
    };

    age.secrets."pushover-initrd-user" = lib.mkIf cfg.notify {
      rekeyFile = inputs.self.outPath + "/secrets/pushover/user-key.age";
      symlink = false;
      path = "/boot/pushover-initrd-user";
    };

    boot.initrd.secrets = lib.mkIf cfg.notify {
      "/boot/pushover-initrd-app" = "/boot/pushover-initrd-app";
      "/boot/pushover-initrd-user" = "/boot/pushover-initrd-user";
    };

    # SSH host key on /boot (unencrypted ESP) — must be readable before ZFS unlock.
    age.secrets.initrd-ssh-host-key = {
      owner = "root";
      group = "root";
      symlink = false;
      path = "/boot/initrd-ssh-host-key";
      generator.script = "ssh-ed25519";
    };

    age.secrets.zroot-encryption-key = {
      rekeyFile = config.node.secretsDir + "/zroot-encryption-key.age";
      # dont keep this key on the host, only used by apps/unlock-initrd.nix
      intermediary = true;
    };
  };
}
