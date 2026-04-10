{ lib, pkgs, ... }:
let
  tex = pkgs.texlive.combined.scheme-full;
in
{
  # Import shared configs
  imports = [
    ../common/shell.nix
    ../common/nvim.nix
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

    # Add Homebrew to PATH for Darwin
    sessionPath = [
      "/opt/homebrew/bin"
    ];
  };
}
