{
  config,
  lib,
  inputs,
  globals,
  nodes,
  profiles,
  nomadCfg,
  ...
}:
{
  imports = [
    inputs.microvm.nixosModules.host
  ];

  guests =
    let
      mkGuest = guestName: guestCfg: {
        autostart = true;
        zfs."/state" = {
          pool = "zroot";
          dataset = "local/guests/${guestName}";
        };
        zfs."/persist" = {
          pool = "zroot";
          dataset = "safe/guests/${guestName}";
        };
        modules = with profiles; [
          common
          impermanence
          ./guests/common.nix
          ./guests/${guestName}.nix
          {
            node.guest = true;
            node.secretsDir = ./secrets/${guestName};
            networking.nftables.firewall = {
              zones.untrusted.interfaces = lib.mapAttrsToList (
                ifaceName: _: ifaceName
              ) config.guests.${guestName}.microvm.interfaces;
            };
          }
          guestCfg
        ];
      };

      mkMicrovm = guestName: id: {
        ${guestName} = mkGuest guestName { node.id = id; } // {
          microvm.system = "x86_64-linux";
          microvm.interfaces.eth0 = {
            bridge = "serverBr";
          };

          extraSpecialArgs = {
            inherit (inputs.self.pkgs.x86_64-linux) lib;
            inherit
              inputs
              globals
              nodes
              profiles
              nomadCfg
              ;
          };
        };
      };
    in
    lib.mkMerge [
      (mkMicrovm "nomad" 2561) # + 0.0.10.1 from base
    ];

  systemd.tmpfiles.rules =
    let
      guestNames = builtins.attrNames config.guests;
      createRulesForGuest = guestName: [
        "d /guests/${guestName}/persist/var/lib/nixos 0755 root root -"
        "d /guests/${guestName}/state/var/log 0755 root root -"
      ];
    in
    lib.flatten (map createRulesForGuest guestNames);
}
