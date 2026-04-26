{
  config,
  profiles,
  ...
}:
{
  networking.hostName = config.node.name;

  # All guests want to be in the nebula mesh, and part of consul cluster
  imports = [
    profiles.services.consul-client
  ];

  globals.nebula.mesh.hosts.${config.node.name} = {
    inherit (config.node) id;
  };

  networking.useNetworkd = true;
  system.stateVersion = "25.05";
}
