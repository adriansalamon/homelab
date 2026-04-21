{
  inputs,
  ...
}:
let
  hyper = "rcmd + rctrl + ralt";
in
{
  imports = [
    inputs.paneru.darwinModules.paneru
  ];

  services.skhd = {
    enable = true;
    skhdConfig = ''
      # Open new terminal - HYPER + Return
      ${hyper} - return : open -na Ghostty

      # Close current window (Cmd+W) - HYPER + Q
      ${hyper} - q : osascript -e 'tell application "System Events" to keystroke "w" using command down'

      # Close entire application (Cmd+Q) - HYPER + Shift + Q
      ${hyper} + shift - q : osascript -e 'tell application "System Events" to keystroke "q" using command down'

      # Open browser - HYPER + B
      ${hyper} - b : open -a "Firefox"

      # Open file manager - HYPER + N
      ${hyper} - n : open -a "Finder"
    '';
  };

  services.paneru = {
    enable = true;
    settings = {
      options = {
        focus_follows_mouse = true;
        mouse_follows_focus = true;
        preset_column_widths = [
          0.25
          0.33
          0.5
          0.66
          0.75
        ];
      };
      decorations.active.border = {
        enabled = true;
        color = "#89b4fa"; # Catppuccin blue, matching Niri focus ring
        opacity = 1.0;
        width = 2.0;
        radius = "auto";
      };

      windows.all = {
        title = ".*";
        horizontal_padding = 5;
        vertical_padding = 5;
      };

      bindings = {
        # Focus - HYPER + hjkl
        window_focus_west  = "${hyper} - h";
        window_focus_east  = "${hyper} - l";
        window_focus_north = "${hyper} - k";
        window_focus_south = "${hyper} - j";

        # Swap - HYPER + Shift + hjkl
        window_swap_west  = "${hyper} + shift - h";
        window_swap_east  = "${hyper} + shift - l";
        window_swap_north = "${hyper} + shift - k";
        window_swap_south = "${hyper} + shift - j";

        window_resize   = "${hyper} - r";
        window_shrink   = "${hyper} - e";
        window_center   = "${hyper} - c";
        window_fullwidth = "${hyper} - m";
        window_manage   = "${hyper} - t";

        # Display focus - HYPER + G
        mouse_nextdisplay = "${hyper} - g";

        # Virtual workspaces - HYPER + y/u
        window_virtual_north    = "${hyper} - y";
        window_virtual_south    = "${hyper} - u";
        window_virtualmove_north = "${hyper} + shift - y";
        window_virtualmove_south = "${hyper} + shift - u";

        # Stack - HYPER + i/o
        window_stack    = "${hyper} - i";
        window_unstack  = "${hyper} - o";
        window_equalize = "${hyper} - equal";
        window_snap     = "${hyper} - backslash";

        quit = "ctrl + alt - q";
      };
    };
  };
}
