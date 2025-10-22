{
  config,
  pkgs,
  nodes,
  lib,
  globals,
  ...
}:
let
  inherit (lib)
    filterAttrs
    mapAttrsToList
    ;
in
{
  # Mosquitto for MQTT

  age.secrets.mosquitto-home-assistant-pass = {
    mode = "440";
    owner = "hass";
    group = "mosquitto";
    generator.script = "alnum";
  };

  age.secrets.mosquitto-tasmota-pass = {
    mode = "440";
    owner = "hass";
    group = "mosquitto";
    generator.script = "alnum";
  };

  age.secrets."home-assistant-secrets.yaml" = {
    generator = {
      dependencies = [ nodes.zeus-auth.config.age.secrets.hass-oidc-client-secret ];
      script =
        {
          lib,
          decrypt,
          deps,
          ...
        }:
        lib.concatMapStrings (secret: ''
          echo "${lib.escapeShellArg secret.name}": "$(${decrypt} ${lib.escapeShellArg secret.file})" \
            || die "Failure while aggregating secrets"
        '') deps;
    };
    owner = "hass";
  };

  services.mosquitto = {
    enable = true;
    persistence = true;
    listeners = lib.singleton {
      acl = [ "pattern readwrite #" ];
      users = {
        home_assistant = {
          passwordFile = config.age.secrets.mosquitto-home-assistant-pass.path;
          acl = [ "readwrite #" ];
        };
        tasmota = {
          passwordFile = config.age.secrets.mosquitto-tasmota-pass.path;
          acl = [ "readwrite #" ];
        };
      };
      settings.allow_anonymous = false;
    };
  };

  # Home Assistant

  environment.persistence."/persist".directories = lib.singleton {
    directory = config.services.home-assistant.configDir;
    user = "hass";
    group = "hass";
    mode = "0700";
  };

  services.avahi = {
    enable = true;
  };

  services.home-assistant = {
    enable = true;
    extraComponents = [
      "met"
      "snapcast"
      "octoprint"
      "spotify"
      "verisure"
      "mqtt"
      "braviatv"
      "cast"
      "isal"
      "tasmota"
      "unifi"
      "apple_tv"
      "homekit"
      "homekit_controller"
      "mobile_app"
      "esphome"
    ];

    customLovelaceModules = with pkgs.home-assistant-custom-lovelace-modules; [
      apexcharts-card
      bubble-card
      button-card
      card-mod
      clock-weather-card
      hourly-weather
      mini-graph-card
      mini-media-player
      multiple-entity-row
      mushroom
      weather-card
      weather-chart-card
    ];

    customComponents = with pkgs.home-assistant-custom-components; [
      (pkgs.home-assistant.python.pkgs.callPackage ./hass-components/auth_oidc.nix { })
      prometheus_sensor
    ];

    config = {
      default_config = { };

      http = {
        use_x_forwarded_for = true;
        trusted_proxies = mapAttrsToList (_: hostCfg: hostCfg.ipv4) (
          filterAttrs (_: cfg: builtins.elem "reverse-proxy" cfg.groups) globals.nebula.mesh.hosts
        );
      };

      lovelace.mode = "yaml";

      frontend = {
        themes = "!include_dir_merge_named themes";
      };

      "automation ui" = "!include automations.yaml";
      "scene ui" = "!include scenes.yaml";
      "script ui" = "!include scripts.yaml";

      auth_oidc = {
        client_id = "hass";
        client_secret = "!secret hass-oidc-client-secret";
        discovery_url = "https://auth.${globals.domains.main}/.well-known/openid-configuration";
        roles = {
          admin = "admin";
        };
        features.automatic_user_linking = true;
      };
    };
  };

  systemd.services.home-assistant = {
    preStart = lib.mkBefore ''
      if [[ -e ${config.services.home-assistant.configDir}/secrets.yaml ]]; then
        rm ${config.services.home-assistant.configDir}/secrets.yaml
      fi
      cp ${
        config.age.secrets."home-assistant-secrets.yaml".path
      } ${config.services.home-assistant.configDir}/secrets.yaml
      touch -a ${config.services.home-assistant.configDir}/{automations,scenes,scripts,manual}.yaml
    '';
  };

  consul.services = {
    home-assistant = {
      port = 8123;
      tags = [
        "traefik.enable=true"
        "traefik.http.routers.hass.rule=Host(`home-assistant.local.${globals.domains.main}`)"
        "traefik.http.routers.hass.entrypoints=websecure"
      ];
    };
    mqtt = {
      port = 1883;
      tags = [
        "traefik.enable=true"
        "traefik.tcp.routers.mqtt.rule=HostSNI(`*`)"
        "traefik.tcp.routers.mqtt.entrypoints=mqtt"
      ];
    };
  };

  globals.nebula.mesh.hosts.orpheus.firewall.inbound = [
    {
      port = 1705; # Snapcast tcp
      proto = "tcp";
      host = "zeus-home-assistant";
    }
  ];

  globals.nebula.mesh.hosts.zeus-home-assistant.firewall.inbound = [
    {
      port = 1883; # MQTT
      proto = "tcp";
      group = "reverse-proxy";
    }
    {
      port = 8123; # Home Assistant
      proto = "tcp";
      group = "reverse-proxy";
    }
  ];
}
