{
  config,
  globals,
  nodes,
  lib,
  ...
}:
let
  host = config.node.name;
  port = 8234;
in
{

  environment.persistence."/persist".directories = lib.singleton {
    directory = config.services.zigbee2mqtt.dataDir;
    user = "zigbee2mqtt";
  };

  age.secrets."mqtt-secrets.yaml" = {
    generator = {
      dependencies = [ nodes.zeus-home-assistant.config.age.secrets.mosquitto-zigbee2mqtt-pass ];
      script =
        {
          lib,
          decrypt,
          deps,
          ...
        }:
        lib.concatMapStrings (secret: ''
          echo "password": "$(${decrypt} ${lib.escapeShellArg secret.file})" \
            || die "Failure while aggregating secrets"
        '') deps;
    };
    owner = "zigbee2mqtt";
  };

  services.zigbee2mqtt = {
    enable = true;

    settings = {
      homeassistant.enabled = true;

      frontend = {
        enabled = true;
        inherit port;
        host = globals.nebula.mesh.hosts.${host}.ipv4;
        url = "https://zigbee2mqtt.local.${globals.domains.main}";
      };

      mqtt = {
        base_topic = "zigbee2mqtt";
        server = "mqtt://mqtt.local.salamon.xyz:1883";
        user = "zigbee2mqtt";
        password = "!${config.age.secrets."mqtt-secrets.yaml".path} password";
      };

      serial = {
        port = "/dev/serial/by-id/usb-ITead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_c0429d73cf8aef119de222ccef8776e9-if00-port0";
        adapter = "zstack";
      };
    };
  };

  consul.services.zigbee2mqtt = {
    inherit port;
    tags = [
      "traefik.enable=true"
      "traefik.http.routers.zigbee2mqtt.rule=Host(`zigbee2mqtt.local.${globals.domains.main}`)"
      "traefik.http.routers.zigbee2mqtt.entrypoints=websecure"
    ];
  };

  globals.nebula.mesh.hosts.${host}.firewall.inbound = [
    {
      inherit port;
      proto = "tcp";
      group = "reverse-proxy";
    }
    {
      inherit port;
      proto = "tcp";
      host = "zeus-home-assistant";
    }
  ];
}
