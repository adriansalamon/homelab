{
  modulesPath,
  ...
}:
let
  host = "hermes";
in
{
  # NAS/storage server
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disk-config.nix
    ./hw.nix
    ./net.nix
    ../../../config
    ../../../config/optional/zfs.nix
    ../../../config/optional/impermanence.nix
    ../../../config/optional/hardware.nix
    ../../../config/optional/consul-client.nix
  ];

  networking.hostId = "b8d0bfb2";

  globals.nebula.mesh.hosts.${host} = {
    id = 8;
  };

  meta.vector.enable = true;
  meta.prometheus.enable = true;

  system.stateVersion = "24.11";
}
