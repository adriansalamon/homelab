{
  lib,
  pkgs,
  ...
}:
let
  tex = pkgs.texlive.combined.scheme-full;
in
{
  # Import shared configs
  imports = [
    ../common/git.nix
    ../common/nvim.nix
    ../common/shell.nix
    ./karabiner.nix
  ];

  services.ssh-agent = {
    enable = true;
    pkcs11Whitelist = [ "${pkgs.yubico-piv-tool}/lib/*" ];
  };

  home.file.".ssh/id_yubikey_piv.pub".text = ''
    ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBDmOgdi09i0CnGRAaXDzkOCJ+XAVDvF3jFKgWMl5yfrxeqczLqk0wB9xqVr4I4TQEYJNkM6TiYzh/e9alknR9apD49m68cB3Jl4CuR4Nygcrl51pw8lSzE9JmtIBhsG1tA== Public key for PIV Authentication
  '';

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."*" = {
      controlMaster = "auto";
      controlPath = "~/.ssh/sockets/%C";
      controlPersist = "10m";
      identityFile = [ "~/.ssh/id_yubikey_piv.pub" ];

      extraOptions = {
        AddKeysToAgent = "yes";
      };
    };
  };

  programs.ghostty = {
    package = pkgs.ghostty-bin;
    enable = true;
    settings = {
      macos-titlebar-style = "tabs";
      window-padding-x = "0";
      window-padding-y = "0";
      theme = "${pkgs.vimPlugins.kanagawa-nvim}/extras/ghostty/kanagawa-dragon";
      font-family = "Lilex Nerd Font Mono";
    };
    installVimSyntax = true;
  };

  home = {
    username = "asalamon";
    homeDirectory = lib.mkForce "/Users/asalamon";
    stateVersion = "25.05";

    activation.sshSocketsDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p "$HOME/.ssh/sockets"
    '';

    activation.installKeyboardLayout = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p "$HOME/Library/Keyboard Layouts"
      $DRY_RUN_CMD cp -f $VERBOSE_ARG ${./us-intl-nodead.keylayout} "$HOME/Library/Keyboard Layouts/us-intl-nodead.keylayout"
    '';

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
