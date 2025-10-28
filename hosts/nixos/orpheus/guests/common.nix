{
  config,
  profiles,
  ...
}:
{
  networking.hostName = config.node.name;

  # All nodes definetely want to be in the nebula mesh, and part of consul cluster
  imports = [
    profiles.services.consul-client
  ];

  globals.nebula.mesh.hosts.${config.node.name} = {
    inherit (config.node) id;
  };

  # we all want vector logging, but no metrics collection
  meta.vector.enable = true;

  networking.useNetworkd = true;
  system.stateVersion = "24.11";
}
