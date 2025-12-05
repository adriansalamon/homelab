{
  config,
  pkgs,
  nomadCfg,
  lib,
  globals,
  ...
}:
let
  inherit (lib)
    filterAttrs
    mapAttrsToList
    mapAttrs'
    flip
    ;

  passwdSecretName = "authelia-hass-oidc-client-secret";

  mqttUsers = {
    home-assistant = { };
    tasmota = { };
    zigbee2mqtt = { };
  };

in
{
  # Mosquitto for MQTT

  age.secrets = {
    "home-assistant-secrets.yaml" = {
      generator = {
        dependencies = [ nomadCfg.config.age.secrets.${passwdSecretName} ];
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
  }
  // flip mapAttrs' mqttUsers (
    name: cfg: {
      name = "mosquitto-${name}-pass";
      value = {
        mode = "440";
        owner = "hass";
        group = "mosquitto";
        generator.script = "alnum";
      };
    }
  );

  services.mosquitto = {
    enable = true;
    persistence = true;
    listeners = lib.singleton {
      acl = [ "pattern readwrite #" ];
      users = flip mapAttrs' mqttUsers (
        name: cfg: {
          name = flip lib.strings.replaceChars name { "-" = "_"; };
          value = {
            passwordFile = config.age.secrets."mosquitto-${name}-pass".path;
            acl = [ "readwrite #" ];
          };
        }
      );
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
      "apple_tv"
      "bluetooth"
      "bluetooth_adapters"
      "braviatv"
      "cast"
      "esphome"
      "homekit"
      "homekit_controller"
      "isal"
      "met"
      "mobile_app"
      "mqtt"
      "octoprint"
      "snapcast"
      "spotify"
      "tasmota"
      "unifi"
      "verisure"
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

    customComponents =
      let
        inherit (pkgs.home-assistant.python.pkgs) callPackage;
      in
      with pkgs.home-assistant-custom-components;
      [
        (callPackage ./hass-components/auth_oidc.nix { })
        (callPackage ./hass-components/hass-plejd.nix {
          pyplejd = (callPackage ./hass-components/pyplejd.nix { });
        })
        (callPackage ./hass-components/wiim.nix { })
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
        client_secret = "!secret ${passwdSecretName}";
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
