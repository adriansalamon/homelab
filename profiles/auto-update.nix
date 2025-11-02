{ config, inputs, ... }:
{

  age.secrets = {
    consul-auto-update-token.rekeyFile = inputs.self.outPath + "/secrets/consul/auto-update-token.age";
    pushover-user.rekeyFile = inputs.self.outPath + "/secrets/pushover/user-key.age";
    pushover-app.rekeyFile = inputs.self.outPath + "/secrets/pushover/app-key.age";
  };

  services.nixos-auto-updater = {
    enable = true;

    checkInterval = "*-*-* 00/3:00:00"; # every 3 hours
    lockTimeout = "30m";

    consulAddr = "127.0.0.1:8500";
    consulTokenFile = config.age.secrets.consul-auto-update-token.path;
    pushoverUserFile = config.age.secrets.pushover-user.path;
    pushoverAppFile = config.age.secrets.pushover-app.path;

    healthTimeout = "30s";
  };
}
