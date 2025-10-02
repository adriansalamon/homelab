{
  inputs,
  config,
  modulesPath,
  globals,
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
  ];

  networking.hostId = "b8d0bfb2";

  age.secrets."consul-acl.json" = {
    rekeyFile = inputs.self.outPath + "/secrets/consul/agent.acl.json.age";
    owner = "consul";
  };

  services.consul = {
    enable = true;
    extraConfig = {
      server = false;
      bind_addr = globals.nebula.mesh.hosts.charon.ipv4;
      retry_join = [
        globals.nebula.mesh.hosts.icarus.ipv4
        globals.nebula.mesh.hosts.athena.ipv4
      ];

      acl = {
        enabled = true;
        default_policy = "deny";
      };
    };

    extraConfigFiles = [
      config.age.secrets."consul-acl.json".path
    ];
  };

  globals.nebula.mesh.hosts.${host} = {
    id = 8;
    groups = [ "consul-client" ];
  };

  meta.vector.enable = true;
  meta.prometheus.enable = true;

  system.stateVersion = "24.11";
}
