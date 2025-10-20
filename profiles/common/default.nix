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
    gitMinimal
    curl
    vim
    jq
    lsof
    strace
    iotop
    btop
    tldr
    dnsutils
    neofetch
    lshw
    tcpdump
  ];
}
