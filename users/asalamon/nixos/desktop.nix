{ pkgs, ... }:
{
  # Desktop-specific GUI application configurations

  # GTK theme
  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    gtk4.theme = null; # Use default GTK4 theme
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "capitaine-cursors";
      package = pkgs.capitaine-cursors;
      size = 24;
    };
  };

  # Qt theme
  qt = {
    enable = true;
    platformTheme.name = "gtk";
    style.name = "adwaita-dark";
  };

  # Cursor theme for Wayland/Hyprland
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    name = "capitaine-cursors";
    package = pkgs.capitaine-cursors;
    size = 24;
  };

  # Terminal emulator (kitty)
  programs.kitty = {
    enable = true;
    themeFile = "tokyo_night_night";
    settings = {
      font_family = "JetBrainsMono Nerd Font";
      font_size = 11;
      bold_font = "auto";
      italic_font = "auto";
      bold_italic_font = "auto";

      background_opacity = "0.95";

      # Scrollback
      scrollback_lines = 10000;

      # Window
      remember_window_size = true;
      initial_window_width = 1200;
      initial_window_height = 800;

      # Tab bar
      tab_bar_style = "powerline";
      tab_powerline_style = "slanted";

      # Mouse
      copy_on_select = true;
    };
  };

  # Rofi launcher
  programs.rofi = {
    enable = true;
    package = pkgs.rofi; # rofi-wayland has been merged into rofi
    theme = "Arc-Dark";
    terminal = "${pkgs.kitty}/bin/kitty";
    extraConfig = {
      modi = "drun,run,window";
      show-icons = true;
      drun-display-format = "{name}";
      disable-history = false;
      sidebar-mode = true;
    };
  };

  # File manager settings (via dconf for Thunar)
  dconf.settings = {
    "org/gtk/settings/file-chooser" = {
      sort-directories-first = true;
    };
  };
}
