{
  config,
  lib,
  pkgs,
  inputs,
  globals,
  nodes,
  profiles,
  nomadCfg,
  ...
}:
let
  cfg = config.homeAutomation;
  isSupported = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
in
{
  options.homeAutomation = {
    enable = lib.mkEnableOption "Home Assistant + Mosquitto microVM";

    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Traefik/DNS subdomain for this HA instance, e.g. 'hass-olympus'";
      example = "hass-olympus";
    };

    nodeId = lib.mkOption {
      type = lib.types.int;
      description = "Unique node ID for the microVM guest (determines Nebula IP and MAC address)";
    };

    bridge = lib.mkOption {
      type = lib.types.str;
      default = "lanBr";
      description = "Host bridge interface to attach the microVM to";
    };

    secretsDir = lib.mkOption {
      type = lib.types.path;
      description = "Path to the secrets directory for the home-assistant guest (must contain host.pub)";
      example = lib.literalExpression "./secrets/home-assistant";
    };

    mqttUsers = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options.acl = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "List of ACL rules for this MQTT user";
          };
        }
      );
      default = {
        home-assistant.acl = [ "readwrite #" ];
      };
      description = "MQTT users and their ACL rules. The 'home-assistant' user is required.";
      example = lib.literalExpression ''
        {
          home-assistant.acl = [ "readwrite #" ];
          tasmota.acl = [ "write tasmota/discovery/#" "read cmnd/#" "write stat/#" "write tele/#" ];
          zigbee2mqtt.acl = [ "readwrite zigbee2mqtt/#" "readwrite homeassistant/#" ];
        }
      '';
    };

    extraModules = lib.mkOption {
      type = lib.types.listOf lib.types.unspecified;
      default = [ ];
      description = "Additional NixOS modules to include in the microVM guest configuration";
    };
  };

  config = lib.mkIf (cfg.enable && isSupported) {
    guests.home-assistant = {
      autostart = true;
      zfs."/state" = {
        pool = "zroot";
        dataset = "local/guests/home-assistant";
      };
      zfs."/persist" = {
        pool = "zroot";
        dataset = "safe/guests/home-assistant";
      };
      microvm.system = "x86_64-linux";
      microvm.interfaces.eth0 = {
        bridge = cfg.bridge;
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
        homeAutomationCfg = cfg;
      };
      modules = [
        profiles.nixos
        profiles.impermanence
        {
          node = {
            guest = true;
            inherit (config.node) site;
            id = cfg.nodeId;
            secretsDir = cfg.secretsDir;
          };
          networking.nftables.firewall.zones.untrusted.interfaces = [ "eth0" ];
        }
        ./guest-config.nix
      ]
      ++ cfg.extraModules;
    };
  };
}
