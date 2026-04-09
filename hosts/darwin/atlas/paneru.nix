{
  inputs,
  pkgs,
  ...
}:
let
  # AppleScript to open iTerm, handling Finder integration
  itermScript = pkgs.writeText "iterm.script" ''
    tell application "System Events"
    	set activeApp to name of first application process whose frontmost is true
    end tell

    if activeApp is "Finder" then
    	tell application "Finder"
    		set currentPath to (target of front window as alias)
    	end tell

    	tell application "iTerm"
    		tell application "iTerm"
    			set newWindow to (create window with default profile)
    			tell current session of newWindow
    				write text "cd " & quoted form of POSIX path of currentPath & " && clear"
    			end tell
    		end tell
    		activate
    	end tell

      else
    	if application "iTerm" is not running then
    		tell application "iTerm"
    			activate
    		end tell
    	else
    		tell application "iTerm"
    			create window with default profile
    			activate
    		end tell
    	end if
    end if
  '';
in
{

  imports = [
    inputs.paneru.darwinModules.paneru
  ];

  # Simple Hotkey Daemon for global shortcuts (app launching, etc.)
  services.skhd = {
    enable = true;
    skhdConfig = ''
      # Open new terminal - HYPER + Return
      rcmd + rctrl + ralt - return : osascript ${itermScript}

      # Close current window (Cmd+W) - HYPER + Q
      rcmd + rctrl + ralt - q : osascript -e 'tell application "System Events" to keystroke "w" using command down'

      # Close entire application (Cmd+Q) - HYPER + Shift + Q
      rcmd + rctrl + ralt + shift - q : osascript -e 'tell application "System Events" to keystroke "q" using command down'

      # Open browser - HYPER + B
      rcmd + rctrl + ralt - b : open -a "Firefox"

      # Open file manager - HYPER + N
      rcmd + rctrl + ralt - n : open -a "Finder"
    '';
  };

  services.paneru = {
    enable = true;
    # Paneru configuration
    # See CONFIGURATION.md for a list of all options
    # HYPER key = rcmd + rctrl + ralt (matches Yabai/Niri configs)
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
      decorations = {
        active = {
          border = {
            enabled = true;
            color = "#89b4fa"; # Catppuccin blue, matching Niri focus ring
            opacity = 1.0;
            width = 4.0;
            radius = "auto";
          };
        };
      };

      windows.all = {
        title = ".*";
        horizontal_padding = 5;
      };
      bindings = {
        # Focus windows - HYPER + h/j/k/l (vim keys)
        window_focus_west = "rcmd + rctrl + ralt - h";
        window_focus_east = "rcmd + rctrl + ralt - l";
        window_focus_north = "rcmd + rctrl + ralt - k";
        window_focus_south = "rcmd + rctrl + ralt - j";

        # Swap windows - similar to move
        window_swap_west = "rcmd + rctrl + ralt + shift - h";
        window_swap_east = "rcmd + rctrl + ralt + shift - l";
        window_swap_north = "rcmd + rctrl + ralt + shift - k";
        window_swap_south = "rcmd + rctrl + ralt + shift - j";

        # Window resize mode - HYPER + R
        window_resize = "rcmd + rctrl + ralt - r";
        window_shrink = "rcmd + rctrl + ralt - e";

        # Center window - HYPER + C
        window_center = "rcmd + rctrl + ralt - c";

        # Toggle full width - HYPER + M
        window_fullwidth = "rcmd + rctrl + ralt - m";

        # Toggle floating/tiled - HYPER + T
        window_manage = "rcmd + rctrl + ralt - t";

        # Focus next display - HYPER + G
        mouse_nextdisplay = "rcmd + rctrl + ralt - g";

        # Virtual workspace navigation - HYPER + u/d (up/down)
        # Similar to Niri's vertical workspace switching
        window_virtual_north = "rcmd + rctrl + ralt - u";
        window_virtual_south = "rcmd + rctrl + ralt - d";

        # Move window to virtual workspace - HYPER + Shift + u/d
        window_virtualmove_north = "rcmd + rctrl + ralt + shift - u";
        window_virtualmove_south = "rcmd + rctrl + ralt + shift - d";

        # Stack/Unstack operations - HYPER + . / ,
        # Similar to Niri's consume/expel window features
        window_stack = "rcmd + rctrl + ralt - s";
        window_unstack = "rcmd + rctrl + ralt - x";

        # Equalize windows in stack - HYPER + equal
        window_equalize = "rcmd + rctrl + ralt - equal";

        # Snap window to viewport - HYPER + backslash
        window_snap = "rcmd + rctrl + ralt - backslash";

        # Quit Paneru - Ctrl + Alt + Q
        quit = "ctrl + alt - q";
      };
    };
  };
}
