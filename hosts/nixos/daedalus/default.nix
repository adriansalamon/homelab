{ profiles, ... }:
{
  # Test VPS on Hetzner Cloud for experimenting with ZFS encryption + Nebula initrd unlock.
  # Use the Hetzner KVM console as out-of-band access if networking breaks during initrd.
  imports = with profiles; [
    ./disk-config.nix
    ./hw.nix
    ./net.nix
    nixos
    zfs
    impermanence
  ];

  networking.hostId = "d4ed4ed4";

  boot.initrd.remoteUnlock = {
    enable = true;
    nebula = true;
    notify = true;
  };

  globals.nebula.mesh.hosts.daedalus = {
    id = 12;
    groups = [ ];

    monitor = false;
  };

  system.stateVersion = "25.05";
}
