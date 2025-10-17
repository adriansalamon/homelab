{ config, globals, ... }:
{

  age.secrets.firezone-gateway-token.rekeyFile = ./secrets/firezone-gateway-token.age;

  services.firezone.gateway = {
    enable = false;
    name = config.node.name;
    apiUrl = "wss://firezone-api.${globals.domains.main}/";
    tokenFile = config.age.secrets.firezone-gateway-token.path;
  };

  # Defaults to 8080, but we are using it for traefik
  # systemd.services.firezone-gateway.environment."HEALTH_CHECK_ADDR" = "0.0.0.0:8083";
}
