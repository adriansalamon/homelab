{ pkgs, ... }:
{
  # Enable Niri compositor
  programs.niri.enable = true;

  # XWayland support for X11 applications
  environment.systemPackages = with pkgs; [
    xwayland-satellite

    # Essential desktop applications
    alacritty # Terminal (default Super+T)
    fuzzel # Application launcher (default Super+D)
    swaylock # Screen locker (default Super+Alt+L)
    grim # Screenshot utility
    slurp # Screen area selection
    wl-clipboard # Wayland clipboard utilities

    # File manager
    thunar

    # Browser
    firefox
  ];

  # Display manager configuration (SDDM)
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "breeze";
  };

  # Polkit authentication agent
  security.polkit.enable = true;

  # GNOME Keyring for secret service
  services.gnome.gnome-keyring.enable = true;

  # PAM services for swaylock
  security.pam.services.swaylock = { };

  # XDG Desktop Portal for screen sharing, file pickers, etc.
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
    config.common.default = "*";
  };

  # Enable bluetooth service to start with system
  systemd.services.bluetooth.wantedBy = [ "multi-user.target" ];
}
