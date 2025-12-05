{ lib, pkgs, ... }:
{
  imports = [
    ./zsh.nix
    ./nvim.nix
  ];

  home = {
    username = "asalamon";
    homeDirectory = lib.mkForce "/Users/asalamon";
    stateVersion = "25.05";

    packages = with pkgs; [
      rustup
    ];
  };
}
