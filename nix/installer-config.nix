{ pkgs, globals, ... }:
{
  system.stateVersion = "24.11";
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  boot.loader.systemd-boot.enable = true;

  users.users.root = {
    password = "nixos";
    openssh.authorizedKeys.keys = globals.admin-user.pubkeys;
  };

  environment = {
    variables.EDITOR = "nvim";
    systemPackages = with pkgs; [
      curl
      fzf
      git
      parted
      ripgrep
      tmux
      wget
      neovim
    ];
  };
}
