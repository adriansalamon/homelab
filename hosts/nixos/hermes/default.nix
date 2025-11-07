{
  config,
  modulesPath,
  profiles,
  ...
}:
let
  host = config.node.name;
in
{
  # NAS/storage server
  imports = with profiles; [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disk-config.nix
    ./hw.nix
    ./net.nix
    ./nfs.nix
    ./smb.nix
    ./metrics.nix
    common
    zfs
    impermanence
    hardware
    services.consul-client
    services.seaweedfs.volume
    storage-users
    auto-update
  ];

  networking.hostId = "b8d0bfb2";
  node.site = "olympus";

  globals.nebula.mesh.hosts.${host} = {
    id = 8;
  };

  meta.vector.enable = true;
  meta.telegraf.enable = true;

  system.stateVersion = "24.11";
}
