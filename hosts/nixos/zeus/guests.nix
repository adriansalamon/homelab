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

      mkMicrovm =
        guestName:
        {
          bridge ? "serverBr",
          id,
        }:
        {
          ${guestName} = mkGuest guestName { node.id = id; } // {
            microvm.system = "x86_64-linux";
            microvm.interfaces.eth0 = { inherit bridge; };

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
      (mkMicrovm "unifi" { id = 2049; }) # + 0.0.8.1 from base
      (mkMicrovm "arr" {
        bridge = "vpnBr";
        id = 2050;
      })
      (mkMicrovm "home-assistant" { id = 2051; })
      (mkMicrovm "nomad" { id = 2052; })
      (mkMicrovm "paperless" { id = 2053; })
      (mkMicrovm "loki" { id = 2054; })
      (mkMicrovm "prometheus" { id = 2055; })
      (mkMicrovm "grafana" { id = 2056; })
      (mkMicrovm "forgejo" { id = 2057; })
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
