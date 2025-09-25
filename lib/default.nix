inputs: final: prev:
prev.lib.composeManyExtensions (map (x: import x inputs) [
  ./disk.nix
  ./net.nix
  ./nebula-firewall.nix
  ./helpers.nix
]) final prev
