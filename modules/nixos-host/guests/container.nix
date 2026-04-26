guestName: guestCfg:
{
  pkgs,
  config,
  inputs,
  lib,
  extraModules ? [ ],
  ...
}:
let
  inherit (lib)
    flip
    mapAttrs'
    nameValuePair
    ;
in
{
  hostBridge = guestCfg.container.bridge;
  ephemeral = true;
  privateNetwork = true;
  autoStart = guestCfg.autostart;
  extraFlags = [
    "--uuid=${builtins.substring 0 32 (builtins.hashString "sha256" guestName)}"
  ];
  # Allow tun device for nebula (and any other userspace VPN inside the container)
  additionalCapabilities = [ "CAP_NET_ADMIN" ];
  allowedDevices = [
    {
      node = "/dev/net/tun";
      modifier = "rw";
    }
  ];
  bindMounts = flip mapAttrs' guestCfg.zfs (
    _: zfsCfg:
    nameValuePair zfsCfg.guestMountpoint {
      hostPath = zfsCfg.hostMountpoint;
      isReadOnly = false;
    }
  );
  nixosConfiguration = (import "${inputs.nixpkgs}/nixos/lib/eval-config.nix") {
    specialArgs = guestCfg.extraSpecialArgs;
    prefix = [
      "nodes"
      "${config.node.name}-${guestName}"
      "config"
    ];
    system = null;
    modules = [
      {
        boot.isContainer = true;
        networking.useHostResolvConf = false;
        networking.enableIPv6 = false;

        # Configure the veth interface created by hostBridge (named eth0 inside the container)
        systemd.network.networks."10-eth0" = {
          matchConfig.Name = "eth0";
          networkConfig = {
            Address = guestCfg.container.address;
            Gateway = "172.16.0.1";
            DNS = "1.1.1.1";
          };
        };

        # We cannot force the package set via nixpkgs.pkgs and
        # inputs.nixpkgs.nixosModules.readOnlyPkgs, since some nixosModules
        # like nixseparatedebuginfod depend on adding packages via nixpkgs.overlays.
        # So we just mimic the options and overlays defined by the passed pkgs set.
        nixpkgs.hostPlatform = config.nixpkgs.hostPlatform.system;
        nixpkgs.overlays = pkgs.overlays;
        nixpkgs.config = pkgs.config;

        # Bind the /guest/* paths from above so impermancence doesn't complain.
        # We bind-mount stuff from the host to itself, which is perfectly defined
        # and not recursive. This allows us to have a fileSystems entry for each
        # bindMount which other stuff can depend upon (impermanence adds dependencies
        # to the state fs).
        fileSystems = flip mapAttrs' guestCfg.zfs (
          _: zfsCfg:
          nameValuePair zfsCfg.guestMountpoint {
            neededForBoot = true;
            fsType = "none";
            device = zfsCfg.guestMountpoint;
            options = [ "bind" ];
          }
        );

        node.name = guestCfg.name;

        #systemd.network.networks = listToAttrs (
        #  flip map guestCfg.networking.links (
        #    name:
        #    nameValuePair "10-${name}" {
        #      matchConfig.Name = name;
        #      DHCP = "yes";
        #      # XXX: Do we really want this?
        #      dhcpV4Config.UseDNS = false;
        #      dhcpV6Config.UseDNS = false;
        #      ipv6AcceptRAConfig.UseDNS = false;
        #      networkConfig = {
        #      IPv6PrivacyExtensions = "yes";
        #      MulticastDNS = true;
        #      IPv6AcceptRA = true;
        #    };
        #     linkConfig.RequiredForOnline = "routable";
        #    }
        #  )
        #);
      }
    ]
    ++ guestCfg.modules
    ++ extraModules;
  };
}
