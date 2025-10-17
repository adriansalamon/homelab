{ globals, ... }:
let
  port = 2283;
in
{

  environment.persistence."/persist".directories = [
    {
      directory = "/media/immich-data";
      user = "immich";
      group = "immich";
      mode = "0700";
    }
    {
      directory = "/var/lib/redis-immich";
      user = "redis-immich";
      group = "redis-immich";
      mode = "0700";
    }
  ];

  environment.persistence."/state".directories = [
    {
      directory = "/var/cache/immich/";
      user = "immich";
      group = "immich";
      mode = "0700";
    }
  ];

  fileSystems."/mnt/freenas02/adrian_bilder" = {
    device = "${globals.nebula.mesh.hosts.hermes.ipv4}:/data/tank02/homes/adrian/Bilder";
    fsType = "nfs";
  };

  fileSystems."/mnt/freenas03/adrian_bilder" = {
    device = "${globals.nebula.mesh.hosts.hermes.ipv4}:/data/tank03/adrian/Images";
    fsType = "nfs";
  };

  services.immich = {
    inherit port;
    enable = true;
    host = "0.0.0.0";
    mediaLocation = "/media/immich-data";
  };

  globals.monitoring.http.immich = {
    url = "https://immich.${globals.domains.main}/";
    network = "external";
    expectedBodyRegex = "To use Immich";
  };

  consul.services.immich = {
    inherit port;
    tags = [
      "traefik.enable=true"
      "traefik.external=true"
      "traefik.http.routers.immich.rule=Host(`immich.${globals.domains.main}`)"
      "traefik.http.routers.immich.entrypoints=websecure"
    ];
  };

  globals.nebula.mesh.hosts.zeus.firewall.inbound = [
    {
      port = builtins.toString port;
      proto = "tcp";
      group = "reverse-proxy";
    }
  ];

  meta.backups.storageboxes."cloud-backups" = {
    subuser = "immich";
    paths = [ "/media/immich-data" ];
  };
}
