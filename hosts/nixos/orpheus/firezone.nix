{ config, ... }:
{

  age.secrets.firezone-gateway-token.rekeyFile = ./secrets/firezone-gateway-token.age;

  services.firezone.gateway = {
    enable = true;
    name = "orpheus";
    apiUrl = "wss://api.firezone.dev/";
    tokenFile = config.age.secrets.firezone-gateway-token.path;
  };

  systemd.services.firezone-gateway.environment = {
    FIREZONE_ID = "cd458605-b3be-4a76-a779-cc66a6430cb0";
  };
}
