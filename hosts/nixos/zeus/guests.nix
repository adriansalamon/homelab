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

  homeAutomation = {
    enable = true;
    subdomain = "home-assistant.local";
    nodeId = 2051;
    bridge = "lanBr";
    secretsDir = ./secrets/home-assistant;
    mqttUsers = {
      home-assistant.acl = [ "readwrite #" ];
      tasmota.acl = [
        "write tasmota/discovery/#"
        "read cmnd/#"
        "write stat/#"
        "write tele/#"
      ];
      zigbee2mqtt.acl = [
        "readwrite zigbee2mqtt/#"
        "readwrite homeassistant/#"
      ];
      husdata-olympus.acl = [
        "read +/HP/CMD/#"
        "readwrite +/HP/#"
        "readwrite homeassistant/#"
      ];
      husdata-arcadia.acl = [
        "read +/HP/CMD/#"
        "readwrite +/HP/#"
        "readwrite homeassistant/#"
      ];
    };
    extraModules = [
      {
        globals.nebula.mesh.hosts.orpheus.firewall.inbound = [
          {
            port = 1705;
            proto = "tcp";
            host = "zeus-home-assistant";
          }
        ];
      }
    ];
  };

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
      (mkMicrovm "paperless" { id = 2053; })
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
