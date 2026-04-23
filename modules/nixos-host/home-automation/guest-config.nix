# NixOS config that runs inside the home-assistant microVM guest.
# homeAutomationCfg is passed via extraSpecialArgs from the host module.
{
  config,
  pkgs,
  nomadCfg,
  lib,
  globals,
  profiles,
  homeAutomationCfg,
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
  inherit (homeAutomationCfg) mqttUsers;

  hassComponents =
    let
      inherit (pkgs.home-assistant.python.pkgs) callPackage;
    in
    {
      auth_oidc = callPackage ./hass-components/auth_oidc.nix { };
      hass-plejd = callPackage ./hass-components/hass-plejd.nix {
        pyplejd = callPackage ./hass-components/pyplejd.nix { };
      };
      wiim = callPackage ./hass-components/wiim.nix {
        pywiim = callPackage ./hass-components/pywiim.nix { };
      };
    };
in
{
  imports = [
    profiles.services.consul-client
  ];

  networking.hostName = config.node.name;
  meta.vector.enable = true;
  system.stateVersion = "24.11";

  globals.nebula.mesh.hosts.${config.node.name} = {
    inherit (config.node) id;
    firewall.inbound = [
      # todo: remove
      {
        port = 1883;
        proto = "tcp";
        group = "reverse-proxy";
      }
      {
        port = 8123;
        proto = "tcp";
        group = "reverse-proxy";
      }
    ];
  };

  age.secrets = {
    "home-assistant-secrets.yaml" = {
      generator = {
        dependencies = [
          nomadCfg.config.age.secrets.${passwdSecretName}
        ]
        ++ mapAttrsToList (name: _: config.age.secrets."mosquitto-${name}-pass") mqttUsers;
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
    name: _: {
      name = "mosquitto-${name}-pass";
      value = {
        mode = "440";
        owner = "hass";
        group = "mosquitto";
        generator.script = "alnum";
      };
    }
  );

  # Mosquitto

  environment.persistence."/state".directories = lib.singleton {
    directory = config.services.mosquitto.dataDir;
    user = "mosquitto";
    group = "mosquitto";
    mode = "0700";
  };

  services.mosquitto = {
    enable = true;
    persistence = true;
    listeners = lib.singleton {
      users = flip mapAttrs' mqttUsers (
        name: cfg: {
          name = builtins.replaceStrings [ "-" ] [ "_" ] name;
          value = {
            passwordFile = config.age.secrets."mosquitto-${name}-pass".path;
            inherit (cfg) acl;
          };
        }
      );
      settings.allow_anonymous = false;
    };
  };

  networking.firewall.allowedTCPPorts = [ 1883 ];

  # Home Assistant

  environment.persistence."/persist".directories = lib.singleton {
    directory = config.services.home-assistant.configDir;
    user = "hass";
    group = "hass";
    mode = "0700";
  };

  services.avahi.enable = true;

  services.home-assistant = {
    enable = true;
    extraComponents = [
      "apple_tv"
      "anthropic"
      "bluetooth"
      "bluetooth_adapters"
      "braviatv"
      "cast"
      "daikin"
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
      "smhi"
      "tasmota"
      "trafikverket_weatherstation"
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

    customComponents = with pkgs.home-assistant-custom-components; [
      hassComponents.auth_oidc
      hassComponents.hass-plejd
      hassComponents.wiim
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

      lovelace.resource_mode = "yaml";

      frontend.themes = "!include_dir_merge_named themes";

      "automation ui" = "!include automations.yaml";
      "scene ui" = "!include scenes.yaml";
      "script ui" = "!include scripts.yaml";

      auth_oidc = {
        client_id = "hass";
        client_secret = "!secret ${passwdSecretName}";
        discovery_url = "https://auth.${globals.domains.main}/.well-known/openid-configuration";
        roles.admin = "admin";
        features = {
          automatic_user_linking = true;
          automatic_person_creation = true;
        };
        claims = {
          display_name = "name";
          username = "preferred_username";
          groups = "groups";
        };
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
        "traefik.http.routers.hass-${config.node.site}.rule=Host(`${homeAutomationCfg.subdomain}.${globals.domains.main}`)"
        "traefik.http.routers.hass-${config.node.site}.entrypoints=websecure"
      ];
    };
    # todo: remove
    mqtt = {
      port = 1883;
      tags = [
        "traefik.enable=true"
        "traefik.tcp.routers.mqtt.rule=HostSNI(`*`)"
        "traefik.tcp.routers.mqtt.entrypoints=mqtt"
      ];
    };
  };

}
