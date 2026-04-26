{
  pkgs,
  profiles,
  ...
}:
let
  nanobotPort = 18790; # WebSocket/WebUI port
  nanobotUser = "nanobot";
in
{
  imports = [
    profiles.storage-users
  ];

  environment.systemPackages = [
    pkgs.comma
  ];

  programs.nix-ld.enable = true;

  # Create nanobot user
  users.users.${nanobotUser} = {
    isSystemUser = true;
    group = nanobotUser;
    home = "/var/lib/nanobot";
    createHome = true;
  };
  users.groups.${nanobotUser} = { };

  # Persistence for nanobot data
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/nanobot"
      "/etc/nanobot"
    ];
  };

  # nanobot service
  systemd.services.nanobot = {
    description = "nanobot AI Agent";
    after = [
      "network.target"
    ];
    serviceConfig = {
      Type = "simple";
      User = nanobotUser;
      Group = nanobotUser;
      WorkingDirectory = "/var/lib/nanobot";
      ExecStartPre = "${pkgs.nanobot}/bin/nanobot status";
      ExecStart = "${pkgs.nanobot}/bin/nanobot gateway";
      Restart = "always";
      RestartSec = 10;
      # Security hardening
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [
        "/var/lib/nanobot"
        "/tmp"
      ];
      Environment = [
        "PATH=${pkgs.coreutils}/bin:${pkgs.bash}/bin:${pkgs.nix}/bin:${pkgs.python3}/bin:${pkgs.nodejs}/bin:${pkgs.comma}/bin"
        "NIX_SHELL=1"
      ];
    };
    wantedBy = [ "multi-user.target" ];
  };

  globals.nebula.mesh.hosts.daedalus-nanobot = {
    groups = [ "nanobot" ];
  };

  # Firewall: allow WebSocket/WebUI port
  globals.nebula.mesh.hosts.daedalus-nanobot.firewall = {
    inbound = [
      {
        port = nanobotPort;
        proto = "tcp";
        group = "network-admin";
      }
    ];
  };

  # Consul service registration
  consul.services.nanobot = {
    port = nanobotPort;
    tags = [ ];
    checks = [
      {
        name = "nanobot";
        interval = "30s";
        timeout = "5s";
        http = "http://localhost:${toString nanobotPort}/health";
      }
    ];
  };
}
