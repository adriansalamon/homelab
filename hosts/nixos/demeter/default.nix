{
  modulesPath,
  profiles,
  ...
}:
{
  # Backup NAS/storage server
  imports = with profiles; [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disk-config.nix
    ./hw.nix
    ./atticd.nix
    ./db.nix
    ./net.nix
    ./guests.nix
    common
    zfs
    impermanence
    hardware
    services.consul-client
  ];

  meta.usenftables = false;

  networking.hostId = "40f61b93";

  globals.nebula.mesh.hosts.demeter = {
    id = 3;
  };

  meta.vector.enable = true;
  meta.telegraf.enable = true;

  system.stateVersion = "24.11";
}
