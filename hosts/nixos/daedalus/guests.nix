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
          nixos
          impermanence
          ./guests/common.nix
          ./guests/${guestName}.nix
          {
            node.guest = true;
            node.secretsDir = ./secrets/${guestName};
          }
          guestCfg
        ];
      };

      mkContainer =
        guestName:
        {
          bridge ? "serverBr",
          id,
          address,
        }:
        {
          ${guestName} =
            mkGuest guestName {
              node.id = id;
            }
            // {
              backend = "container";
              container.bridge = bridge;
              container.address = address;
              #microvm.system = "x86_64-linux";
              #microvm.interfaces.eth0 = { inherit bridge; };

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
      (mkContainer "claude-code" {
        bridge = "serverBr";
        id = 2305;
        address = "172.16.0.2/24";
      })
      (mkContainer "nanobot" {
        bridge = "serverBr";
        id = 2306;
        address = "172.16.0.3/24";
      })
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
