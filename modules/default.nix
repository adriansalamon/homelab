{ ... }:
{
  imports = [
    ./consul-service.nix
    ./global.nix
    ./kea-ddns-consul.nix
    ./nebula.nix
    ./nftables.nix
    ./node.nix
    ./vector.nix
    ./prometheus.nix
  ];
}
