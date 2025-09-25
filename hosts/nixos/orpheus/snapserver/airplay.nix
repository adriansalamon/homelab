{ pkgs, ... }:
{

  services.avahi = {
    enable = true;
    openFirewall = true;
    reflector = true;
    publish = {
      enable = true;
      userServices = true;
    };
  };

  systemd.services = {
    nqptp = {
      description = "Network Precision Time Protocol for Shairport Sync";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.nqptp}/bin/nqptp";
        Restart = "always";
        RestartSec = "5s";
      };
    };
  };

  # I think we need this
  networking.firewall = {
    allowedTCPPorts = [
      3689
      5353
      5000
    ];
    allowedUDPPorts = [ 5353 ];
    allowedTCPPortRanges = [
      {
        from = 7000;
        to = 7001;
      }
      {
        from = 32768;
        to = 60999;
      }
    ];
    allowedUDPPortRanges = [
      {
        from = 319;
        to = 320;
      }
      {
        from = 6000;
        to = 6009;
      }
      {
        from = 32768;
        to = 60999;
      }
    ];
  };
}
