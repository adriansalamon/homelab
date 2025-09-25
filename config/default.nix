{ inputs, pkgs, ... }:
{

  imports = [
    inputs.disko.nixosModules.default
    inputs.agenix.nixosModules.default
    inputs.agenix-rekey.nixosModules.default
    inputs.impermanence.nixosModules.impermanence
    inputs.nixos-nftables-firewall.nixosModules.default
    ./secrets.nix
    ./users.nix
    ./nftables.nix
    ./boot.nix
    ../modules
  ];

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

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nix.settings.auto-optimise-store = true;

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

}
