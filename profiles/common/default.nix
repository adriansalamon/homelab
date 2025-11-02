{
  inputs,
  pkgs,
  lib,
  ...
}:
{

  imports = [
    inputs.disko.nixosModules.default
    inputs.agenix.nixosModules.default
    inputs.agenix-rekey.nixosModules.default
    inputs.impermanence.nixosModules.impermanence
    inputs.nixos-nftables-firewall.nixosModules.default
    ../../modules
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
    neofetch
    strace
    tcpdump
    tldr
    vim
    gitMinimal
  ];
}
