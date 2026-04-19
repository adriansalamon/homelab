{
  pkgs,
  profiles,
  ...
}:
{
  # Main VM host
  node.site = "olympus";

  imports = [
    ./hardware-config.nix
    ./disk-config.nix
    ./jellyfin.nix
    ./immich.nix
    ./services
    ./guests.nix
    ./net.nix
  ]
  ++ (with profiles; [
    nixos
    zfs
    impermanence
    hardware
    storage-users
    services.consul-client
    auto-update
    services.forgejo-runner
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

  services.nomad-client = {
    enable = true;
    isMicrovm = false;
    macvlanMaster = "serverBr";
  };

  meta.vector.enable = true;
  meta.telegraf.enable = true;

  system.stateVersion = "24.11";
}
