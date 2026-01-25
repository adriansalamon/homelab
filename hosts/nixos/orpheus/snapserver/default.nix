{
  pkgs,
  lib,
  config,
  globals,
  ...
}:
let
  lanIpv4 = globals.sites.erebus.vlans.lan.hosts.orpheus.ipv4;
in
{
  imports = [ ./airplay.nix ];

  # librespot caches Spotify Oauth tokens here
  environment.persistence."/state".directories = lib.singleton {
    directory = "/var/lib/private/snapserver";
    mode = "0700";
  };

  services.snapserver = {
    enable = true;

    # TODO: figure out if we can do this any other way? Now we
    # just expose on LAN for mDNS.
    openFirewall = true;

    settings = {
      http = {
        enabled = true;
        bind_to_address = globals.nebula.mesh.hosts.orpheus.ipv4;
      };

      tcp-control = {
        enabled = true;
        bind_to_address = "0.0.0.0";
      };

      stream = {
        bind_to_address = lanIpv4;

        source = [
          "librespot://${pkgs.librespot}/bin/librespot?name=spotify&devicename=snapcast&bitrate=320&volume=75&cache=/var/lib/snapserver/librespot-cache"
          "airplay://${pkgs.shairport-sync-airplay2}/bin/shairport-sync?name=AirPlay&devicename=snapcast"
        ];
      };
    };
  };

  globals.monitoring.http.snapserver = {
    url = "https://snapcast.local.${globals.domains.main}/";
    network = "internal";
    expectedBodyRegex = "Snapcast web client";
  };

  consul.services.snapcast = {
    inherit (config.services.snapserver.settings.http) port;
    tags = [
      "traefik.enable=true"
      "traefik.http.routers.snapcast.rule=Host(`snapcast.local.${globals.domains.main}`)"
      "traefik.http.routers.snapcast.entrypoints=websecure"
    ];
  };

  globals.nebula.mesh.hosts.orpheus.firewall.inbound = [
    {
      inherit (config.services.snapserver.settings.http) port;
      proto = "tcp";
      group = "reverse-proxy";
    }
    {
      inherit (config.services.snapserver.settings.tcp-control) port;
      proto = "tcp";
      host = "zeus-home-assistant";
    }
  ];
}
