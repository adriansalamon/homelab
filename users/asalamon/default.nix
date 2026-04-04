{ lib, pkgs, ... }:
let
  tex = pkgs.texlive.combined.scheme-full;
in
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
      tex
      consul
      vault-bin
      sops
    ];
  };
}
