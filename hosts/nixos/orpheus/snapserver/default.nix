{ pkgs, ... }:
{
  imports = [ ./airplay.nix ];

  services.snapserver = {
    enable = true;

    # TODO: figure out if we can do this any other way? Now we
    # just expose on LAN for mDNS.
    openFirewall = true;

    streams.spotify = {
      type = "librespot";
      location = "${pkgs.librespot}/bin/librespot";
      query = {
        devicename = "snapcast";
        bitrate = "320";
        volume = "75";
        cache = "/var/lib/snapserver/librespot-cache";
      };
    };

    streams.airplay = {
      type = "airplay";
      location = "${pkgs.shairport-sync-airplay2}/bin/shairport-sync";
      query = {
        name = "AirPlay";
        devicename = "snapcast";
      };
    };
  };

  globals.nebula.mesh.hosts.orpheus.firewall.inbound = [
    {
      port = 1780;
      proto = "tcp";
      group = "reverse-proxy";
    }
  ];
}
