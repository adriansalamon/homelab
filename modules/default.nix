{ ... }:
{
  imports = [
    ./consul-service.nix
    ./global.nix
    ./backups.nix
    ./kea-ddns-consul.nix
    ./nebula.nix
    ./nftables.nix
    ./node.nix
    ./restic-hetzner.nix
    ./vector.nix
    ./prometheus.nix
    ./zrepl.nix
  ];
}
