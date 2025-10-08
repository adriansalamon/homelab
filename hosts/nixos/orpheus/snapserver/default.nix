{
  pkgs,
  config,
  globals,
  ...
}:
let
  lanIpv4 = globals.sites.erebus.vlans.lan.hosts.orpheus.ipv4;
in
{
  imports = [ ./airplay.nix ];

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

      tcp = {
        enabled = true;
        bind_to_address = lanIpv4;
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

  consul.services.snapcast = {
    port = config.services.snapserver.settings.http.port;
    tags = [
      "traefik.enable=true"
      "traefik.http.routers.snapcast.rule=Host(`snapcast.local.${globals.domains.main}`)"
      "traefik.http.routers.snapcast.entrypoints=websecure"
    ];
  };

  globals.nebula.mesh.hosts.orpheus.firewall.inbound = [
    {
      port = builtins.toString config.services.snapserver.settings.http.port;
      proto = "tcp";
      group = "reverse-proxy";
    }
  ];
}
