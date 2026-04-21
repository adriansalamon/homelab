{ lib, pkgs, ... }:
let
  tex = pkgs.texlive.combined.scheme-full;
in
{
  # Import shared configs
  imports = [
    ../common/git.nix
    ../common/nvim.nix
    ../common/shell.nix
  ];

  services.ssh-agent = {
    enable = true;
    pkcs11Whitelist = [ "${pkgs.yubico-piv-tool}/lib/*" ];
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."*".extraOptions = {
      PKCS11Provider = "${pkgs.yubico-piv-tool}/lib/libykcs11.dylib";
      AddKeysToAgent = "yes";
    };
  };

  programs.ghostty = {
    package = pkgs.ghostty-bin;
    enable = true;
    settings = {
      macos-titlebar-style = "tabs";
      window-padding-x = "0";
      window-padding-y = "0";
    };
    installVimSyntax = true;
  };

  home = {
    username = "asalamon";
    homeDirectory = lib.mkForce "/Users/asalamon";
    stateVersion = "25.05";

    packages = with pkgs; [
      consul
      rustup
      sops
      tex
      vault-bin
      yubico-piv-tool
    ];

    shellAliases = {
      ykload = "ssh-add -s ${pkgs.yubico-piv-tool}/lib/libykcs11.dylib";
    };

    # Add Homebrew to PATH for Darwin
    sessionPath = [
      "/opt/homebrew/bin"
    ];
  };
}
