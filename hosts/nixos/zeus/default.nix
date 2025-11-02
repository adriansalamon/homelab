{
  inputs,
  pkgs,
  profiles,
  ...
}:
{
  # Main VM host

  imports = [
    inputs.microvm.nixosModules.host
    ./hardware-config.nix
    ./disk-config.nix
    ./jellyfin.nix
    ./immich.nix
    ./services
    ./guests.nix
    ./net.nix
  ]
  ++ (with profiles; [
    common
    zfs
    impermanence
    hardware
    storage-users
    services.consul-client
    auto-update
  ]);

  networking.hostId = "49e32584";

  environment.systemPackages = with pkgs; [
    curl
    dnsutils
    gitMinimal
    htop
    ipmitool
    tmux
    vim
    zfs
  ];

  globals.nebula.mesh.hosts.zeus = {
    id = 5;
    groups = [
      "nfs-client"
    ];
  };

  meta.vector.enable = true;
  meta.telegraf.enable = true;

  system.stateVersion = "24.11";
}
