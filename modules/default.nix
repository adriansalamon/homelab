{ ... }:
{
  imports = [
    ./consul-service.nix
    ./global.nix
    ./kea-ddns-consul.nix
    ./nebula.nix
    ./node.nix
    ./vector.nix
    ./prometheus.nix
  ];
}
