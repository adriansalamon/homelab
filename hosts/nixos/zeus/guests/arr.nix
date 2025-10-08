{
  lib,
  pkgs,
  globals,
  ...
}:
let
  inherit (lib) mapAttrsToList flip;

  ports = {
    sonarr = 8989;
    radarr = 7878;
    deluge = 8112;
    prowlarr = 9696;
  };
in
{
  microvm.mem = 1024 * 4;
  microvm.vcpu = 4;

  imports = [
    ../../../../config/optional/storage-users.nix
  ];

  users.users.radarr.extraGroups = [ "media" ];
  users.users.sonarr.extraGroups = [ "media" ];
  users.users.deluge.extraGroups = [ "media" ];

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/radarr";
      mode = "0700";
      user = "radarr";
      group = "radarr";
    }
    {
      directory = "/var/lib/sonarr";
      mode = "0700";
      user = "sonarr";
      group = "sonarr";
    }
    {
      directory = "/var/lib/prowlarr";
      mode = "0700";
      user = "prowlarr";
      group = "prowlarr";
    }
    {
      directory = "/var/lib/deluge";
      mode = "0700";
      user = "deluge";
      group = "deluge";
    }
  ];

  boot.supportedFilesystems = [ "nfs" ];

  globals.nebula.mesh.hosts.zeus-arr.groups = [ "nfs-client" ];

  fileSystems."/mnt/media" = {
    device = "${globals.nebula.mesh.hosts.hermes.ipv4}:/data/tank02/media";
    fsType = "nfs";
    options = [
      "nfsvers=4"
      "x-systemd.automount"
      "noauto"
    ];
  };

  services.radarr = {
    enable = true;
    user = "radarr";
    group = "media";
    settings = {
      auth.method = "External";
      server.port = ports.radarr;
    };
  };

  systemd.services.radarr.serviceConfig.ExecStart =
    lib.mkForce "${pkgs.radarr}/bin/Radarr -nobrowser -data='/var/lib/radarr'";

  services.sonarr = {
    enable = true;
    user = "sonarr";
    group = "media";
    settings = {
      auth.method = "External";
      server.port = ports.sonarr;
    };
  };

  systemd.services.sonarr.serviceConfig.ExecStart =
    lib.mkForce "${pkgs.sonarr}/bin/Sonarr -nobrowser -data='/var/lib/sonarr'";

  users.users.prowlarr = {
    group = "prowlarr";
    isSystemUser = true;
  };
  users.groups.prowlarr = { };

  services.prowlarr = {
    enable = true;
    settings = {
      auth.method = "External";
      server.port = ports.prowlarr;
    };
  };

  systemd.services.prowlarr.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "prowlarr";
    Group = "prowlarr";
  };

  services.deluge = {
    enable = true;
    user = "deluge";
    group = "media";
    web = {
      enable = true;
      port = ports.deluge;
    };
  };

  services.flaresolverr = {
    enable = true;
    port = 8191;
  };

  networking.firewall.allowedTCPPorts = [ globals.sites.olympus.airvpn.port ];

  consul.services = {
    radarr = {
      port = ports.radarr;
      tags = [
        "traefik.enable=true"
        "traefik.http.routers.radarr.rule=Host(`radarr.local.${globals.domains.main}`)"
        "traefik.http.routers.radarr.middlewares=authelia"
      ];
    };
    sonarr = {
      port = ports.sonarr;
      tags = [
        "traefik.enable=true"
        "traefik.http.routers.sonarr.rule=Host(`sonarr.local.${globals.domains.main}`)"
        "traefik.http.routers.sonarr.middlewares=authelia"
      ];
    };
    deluge = {
      port = ports.deluge;
      tags = [
        "traefik.enable=true"
        "traefik.http.routers.deluge.rule=Host(`deluge.local.${globals.domains.main}`)"
        "traefik.http.routers.deluge.middlewares=authelia"
      ];
    };
    prowlarr = {
      port = ports.prowlarr;
      tags = [
        "traefik.enable=true"
        "traefik.http.routers.prowlarr.rule=Host(`prowlarr.local.${globals.domains.main}`)"
        "traefik.http.routers.prowlarr.middlewares=authelia"
      ];
    };
  };

  globals.nebula.mesh.hosts.zeus-arr = {
    config.settings = {
      preferred_ranges = [
        globals.sites.olympus.cidrv4
      ];
    };
  };

  globals.nebula.mesh.hosts.zeus-arr.firewall.inbound = flip mapAttrsToList ports (
    _: port: {
      port = builtins.toString port;
      proto = "tcp";
      group = "reverse-proxy";
    }
  );
}
