{ pkgs, ... }:
{
  # Import all other files in this directory
  imports = [
    ./niri.nix
  ];

  # Base desktop packages
  environment.systemPackages = with pkgs; [
    # Terminal emulators
    kitty

    # Browsers
    firefox

    # File managers
    thunar

    # Basic utilities
    pavucontrol
    networkmanagerapplet

    # Media
    mpv

    # Screenshot/recording
    grim
    slurp
    wl-clipboard

    # PDF viewer
    zathura
  ];

  # Enable sound with pipewire
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # Enable NetworkManager for easy network management
  networking.networkmanager.enable = true;

  # Enable CUPS for printing
  services.printing.enable = true;

  # Enable Bluetooth
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # Enable support for graphics
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Fonts
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-color-emoji
    font-awesome
    source-code-pro
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
  ];

  # Enable dconf for GTK applications
  programs.dconf.enable = true;

  # XDG portal for Wayland
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };
}
