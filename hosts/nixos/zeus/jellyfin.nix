{
  pkgs,
  globals,
  ...
}:
let
  port = 8096;
in
{

  boot.supportedFilesystems = [ "nfs" ];

  users.users.jellyfin.extraGroups = [ "media" ];

  fileSystems."/mnt/media" = {
    device = "${globals.nebula.mesh.hosts.hermes.ipv4}:/data/tank02/media";
    fsType = "nfs";
    options = [
      "nfsvers=4"
      "x-systemd.automount"
      "noauto"
    ];
  };

  environment.systemPackages = [
    pkgs.jellyfin
    pkgs.jellyfin-web
    pkgs.jellyfin-ffmpeg
  ];

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/jellyfin";
      user = "jellyfin";
      group = "jellyfin";
      mode = "0700";
    }
  ];

  environment.persistence."/state".directories = [
    {
      directory = "/var/cache/jellyfin";
      user = "jellyfin";
      group = "jellyfin";
      mode = "0700";
    }
  ];

  services.jellyfin.enable = true;

  globals.monitoring.http.jellyfin = {
    url = "https://jellyfin.${globals.domains.main}/health";
    network = "external";
    expectedBodyRegex = "Healthy";
  };

  consul.services.jellyfin = {
    inherit port;
    tags = [
      "traefik.enable=true"
      "traefik.external=true"
      "traefik.http.routers.jellyfin.rule=Host(`jellyfin.${globals.domains.main}`)"
      "traefik.http.routers.jellyfin.entrypoints=websecure"
      # From https://jellyfin.org/docs/general/post-install/networking/advanced/traefik
      "traefik.http.routers.jellyfin.middlewares=jellyfin-mw"
      "traefik.http.middlewares.jellyfin-mw.headers.customResponseHeaders.X-Robots-Tag=noindex,nofollow,nosnippet,noarchive,notranslate,noimageindex"
      "traefik.http.middlewares.jellyfin-mw.headers.SSLRedirect=true"
      "traefik.http.middlewares.jellyfin-mw.headers.SSLHost=jellyfin.${globals.domains.main}"
      "traefik.http.middlewares.jellyfin-mw.headers.SSLForceHost=true"
      "traefik.http.middlewares.jellyfin-mw.headers.STSSeconds=315360000"
      "traefik.http.middlewares.jellyfin-mw.headers.STSIncludeSubdomains=true"
      "traefik.http.middlewares.jellyfin-mw.headers.STSPreload=true"
      "traefik.http.middlewares.jellyfin-mw.headers.forceSTSHeader=true"
      "traefik.http.middlewares.jellyfin-mw.headers.frameDeny=true"
      "traefik.http.middlewares.jellyfin-mw.headers.contentTypeNosniff=true"
      "traefik.http.middlewares.jellyfin-mw.headers.customresponseheaders.X-XSS-PROTECTION=1"
      "traefik.http.middlewares.jellyfin-mw.headers.customresponseheaders.X-Frame-Options=SAMEORIGIN"
    ];
  };

  globals.nebula.mesh.hosts.zeus.firewall.inbound = [
    {
      inherit port;
      proto = "tcp";
      group = "reverse-proxy";
    }
  ];
}
