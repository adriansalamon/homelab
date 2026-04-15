{
  inputs,
  pkgs,
  lib,
  ...
}:
{

  # Common nixos settings

  imports = [
    inputs.disko.nixosModules.default
    inputs.agenix.nixosModules.default
    inputs.agenix-rekey.nixosModules.default
    inputs.impermanence.nixosModules.impermanence
    inputs.nixos-nftables-firewall.nixosModules.default
    inputs.nebula-nomad-cni.nixosModules.default
    ../../modules/common
    ../../modules/nixos
    ../common
  ]
  ++ lib.collect builtins.isPath (lib.filterAttrs (n: _: n != "default") (lib.rakeLeaves ./.));

  environment.systemPackages = with pkgs; [
    attic-client
    btop
    curl
    dnsutils
    iotop
    jq
    lshw
    lsof
    fastfetch
    strace
    tcpdump
    tldr
    vim
    gitMinimal
  ];
}
