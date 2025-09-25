{ lib, ... }:
{
  imports = [
    ./zsh.nix
  ];

  home = {
    username = "asalamon";
    homeDirectory = lib.mkForce "/Users/asalamon";
    stateVersion = "25.05";

    sessionVariables = {
      EDITOR = "vim";
    };
  };

}
