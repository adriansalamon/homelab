{ pkgs, ... }:
{
  system.stateVersion = "24.11";
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  boot.loader.systemd-boot.enable = true;

  users.users.root = {
    password = "nixos";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICOfx4SWN/ygsiUkWWWRCFcTz/SBBRO0qKirHiYuvr3x"
    ];
  };

  environment = {
    variables.EDITOR = "nvim";
    systemPackages = with pkgs; [
      neovim
      git
      tmux
      parted
      ripgrep
      fzf
      wget
      curl
    ];
  };
}
