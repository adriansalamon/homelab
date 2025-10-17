{ ... }:
{
  imports = [
    ./backups.nix
    ./consul-service.nix
    ./global.nix
    ./kea-ddns-consul.nix
    ./nebula.nix
    ./nftables.nix
    ./node.nix
    ./prometheus.nix
    ./restic-hetzner.nix
    ./rustic-exporter.nix
    ./telegraf.nix
    ./vector.nix
    ./zrepl.nix
  ];
}
