{ globals, ... }:
{
  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/unifi";
      mode = "0700";
      user = "unifi";
      group = "unifi";
    }
  ];

  services.unifi = {
    enable = true;
  };

  globals.monitoring.http.unifi = {
    url = "https://unifi.${globals.domains.main}/";
    network = "external";
    expectedBodyRegex = "UniFi Network";
  };

  consul.services = {
    unifi = {
      port = 8443;
      tags = [
        "traefik.enable=true"
        "traefik.external=true"
        "traefik.http.routers.unifi.rule=Host(`unifi.${globals.domains.main}`)"
        "traefik.http.routers.unifi.entrypoints=websecure"
        "traefik.http.services.unifi.loadbalancer.server.scheme=https"
        "traefik.http.services.unifi.loadbalancer.serversTransport=insecure@file"
      ];
    };
    unifi-inform = {
      port = 8080;
      tags = [
        "traefik.enable=true"
        "traefik.external=true"
        "traefik.http.routers.unifi-inform.rule=Host(`unifi.${globals.domains.main}`) && Path(`/inform`)"
        "traefik.http.routers.unifi-inform.entrypoints=websecure,unifi-inform"
      ];
    };
  };

  globals.nebula.mesh.hosts.zeus-unifi.firewall.inbound = [
    {
      port = "8443";
      proto = "tcp";
      group = "reverse-proxy";
    }
    {
      port = "8080";
      proto = "tcp";
      group = "reverse-proxy";
    }
  ];
}
