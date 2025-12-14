guestName: guestCfg:
{ inputs, lib, ... }:
let
  inherit (lib)
    flip
    mapAttrsToList
    mkDefault
    replaceStrings
    concatStringsSep
    ;
in
{
  specialArgs = guestCfg.extraSpecialArgs;
  pkgs = inputs.self.pkgs.${guestCfg.microvm.system};
  inherit (guestCfg) autostart;
  config = {
    imports = guestCfg.modules ++ [
      (import ./common.nix guestName guestCfg)
      (
        { config, ... }:
        {
          # Set early hostname too, so we can associate those logs to this host and don't get "localhost" entries in loki
          boot.kernelParams = [ "systemd.hostname=${config.networking.hostName}" ];
        }
      )
    ];

    lib.microvm.interfaces = guestCfg.microvm.interfaces;

    microvm = {
      hypervisor = mkDefault "qemu";

      mem = mkDefault (1024 + 2048);
      # This causes QEMU rebuilds which would remove 200MB from the closure but
      # recompiling QEMU every deploy is worse.
      optimize.enable = false;

      # Add a writable store overlay, but since this is always ephemeral
      # disable any store optimization from nix.
      writableStoreOverlay = "/nix/.rw-store";

      interfaces = flip mapAttrsToList guestCfg.microvm.interfaces (
        _:
        { mac, ... }:
        {
          type = "tap";
          id = "vm-${replaceStrings [ ":" ] [ "" ] mac}";
          inherit mac;
        }
      );

      shares = [
        # Share the nix-store of the host
        {
          source = "/nix/store";
          mountPoint = "/nix/.ro-store";
          tag = "ro-store";
        }
      ]
      ++ flip mapAttrsToList guestCfg.zfs (
        _: zfsCfg: {
          source = zfsCfg.hostMountpoint;
          mountPoint = zfsCfg.guestMountpoint;
          tag = builtins.substring 0 16 (builtins.hashString "sha256" zfsCfg.hostMountpoint);
          proto = "virtiofs";
        }
      );
    };

    services.udev.extraRules = concatStringsSep "\n" (
      flip mapAttrsToList guestCfg.microvm.interfaces (
        name: { mac, ... }: ''ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="${mac}", NAME="${name}"''
      )
    );

  };
}
