{ pkgs, ... }:
{
  # Niri configuration file
  # Niri uses KDL (KDL Document Language) for configuration
  xdg.configFile."niri/config.kdl".text = ''
    // Niri configuration
    // HYPER key = Right Ctrl + Right Alt + Right Meta (Super)
    // Set in ZMK as: RC(RA(RGUI))
    // For moves: HYPER + Shift

    input {
        keyboard {
            xkb {
                // You can set layout, options, etc. here if needed
                // layout "us"
            }
        }

        touchpad {
            tap
            dwt
            natural-scroll
            // accel-speed 0.2
        }

        mouse {
            // natural-scroll
            // accel-speed 0.2
        }

        // Set Mod key to Super (default on TTY)
        // We'll use Super+Shift+Ctrl+Alt explicitly for HYPER bindings
        mod-key "Super"
    }

    output "DP-1" {
        // Configure your monitor settings here
        // mode "1920x1080@60"
        // scale 1.0
    }

    layout {
        // Gap between windows
        gaps 16

        // Width of the struts (side borders)
        struts {
            left 64
            right 64
            top 64
            bottom 64
        }

        // Center focused column on the screen
        center-focused-column "never"

        // Preset column widths
        preset-column-widths {
            proportion 0.33333
            proportion 0.5
            proportion 0.66667
        }

        // Default column width
        default-column-width { proportion 0.5; }

        focus-ring {
            width 4
            active-color "#89b4fa"
            inactive-color "#45475a"
        }

        border {
            off
        }
    }

    // Window rules
    window-rule {
        // Float certain apps
        match app-id="pavucontrol"
        open-floating true
    }

    window-rule {
        match app-id="nm-connection-editor"
        open-floating true
    }

    // Prefer no borders on maximized windows
    prefer-no-csd

    // Screenshot path
    screenshot-path "~/Pictures/Screenshots/screenshot-%Y-%m-%d_%H-%M-%S.png"

    // Animations
    animations {
        slowdown 1.0

        workspace-switch {
            spring damping-ratio=1.0 stiffness=1000 epsilon=0.0001
        }

        window-open {
            duration-ms 150
            curve "ease-out-expo"
        }

        window-close {
            duration-ms 150
            curve "ease-out-expo"
        }

        window-movement {
            spring damping-ratio=1.0 stiffness=800 epsilon=0.0001
        }

        window-resize {
            spring damping-ratio=1.0 stiffness=800 epsilon=0.0001
        }

        config-notification-open-close {
            spring damping-ratio=0.6 stiffness=1000 epsilon=0.001
        }
    }

    // Environment variables
    environment {
        // Enable NVIDIA-specific variables if needed
        // LIBVA_DRIVER_NAME "nvidia"
        // __GLX_VENDOR_LIBRARY_NAME "nvidia"
    }

    // Cursor settings
    cursor {
        xcursor-theme "capitaine-cursors"
        xcursor-size 24
    }

    // Key bindings
    // HYPER key = Ctrl+Alt+Super (Right Ctrl + Right Alt + Right Meta in ZMK)
    binds {
        // ===== HYPER Key Bindings =====

        // Open terminal - HYPER + Return
        Ctrl+Alt+Super+Return { spawn "kitty"; }

        // Close window - HYPER + Q
        Ctrl+Alt+Super+Q { close-window; }

        // Focus windows - HYPER + h/j/k/l (vim keys)
        Ctrl+Alt+Super+H { focus-column-left; }
        Ctrl+Alt+Super+L { focus-column-right; }
        Ctrl+Alt+Super+J { focus-window-down; }
        Ctrl+Alt+Super+K { focus-window-up; }

        // Move windows - HYPER + Shift + h/j/k/l
        // Note: In Niri, we move columns left/right and windows up/down within columns
        Ctrl+Alt+Super+Shift+H { move-column-left; }
        Ctrl+Alt+Super+Shift+L { move-column-right; }
        Ctrl+Alt+Super+Shift+J { move-window-down; }
        Ctrl+Alt+Super+Shift+K { move-window-up; }

        // Toggle floating - HYPER + T
        Ctrl+Alt+Super+T { toggle-window-floating; }

        // Fullscreen/Maximize - HYPER + M
        Ctrl+Alt+Super+M { fullscreen-window; }

        // Focus prev/next workspace - HYPER + p/n
        Ctrl+Alt+Super+P { focus-workspace-up; }
        Ctrl+Alt+Super+N { focus-workspace-down; }

        // Focus specific workspace - HYPER + 1-9
        Ctrl+Alt+Super+1 { focus-workspace 1; }
        Ctrl+Alt+Super+2 { focus-workspace 2; }
        Ctrl+Alt+Super+3 { focus-workspace 3; }
        Ctrl+Alt+Super+4 { focus-workspace 4; }
        Ctrl+Alt+Super+5 { focus-workspace 5; }
        Ctrl+Alt+Super+6 { focus-workspace 6; }
        Ctrl+Alt+Super+7 { focus-workspace 7; }
        Ctrl+Alt+Super+8 { focus-workspace 8; }
        Ctrl+Alt+Super+9 { focus-workspace 9; }

        // Move window to specific workspace - HYPER + Shift + 1-9
        Ctrl+Alt+Super+Shift+1 { move-column-to-workspace 1; }
        Ctrl+Alt+Super+Shift+2 { move-column-to-workspace 2; }
        Ctrl+Alt+Super+Shift+3 { move-column-to-workspace 3; }
        Ctrl+Alt+Super+Shift+4 { move-column-to-workspace 4; }
        Ctrl+Alt+Super+Shift+5 { move-column-to-workspace 5; }
        Ctrl+Alt+Super+Shift+6 { move-column-to-workspace 6; }
        Ctrl+Alt+Super+Shift+7 { move-column-to-workspace 7; }
        Ctrl+Alt+Super+Shift+8 { move-column-to-workspace 8; }
        Ctrl+Alt+Super+Shift+9 { move-column-to-workspace 9; }

        // Move window to prev/next workspace - HYPER + Shift + p/n
        Ctrl+Alt+Super+Shift+P { move-column-to-workspace-up; }
        Ctrl+Alt+Super+Shift+N { move-column-to-workspace-down; }

        // Column width adjustments - HYPER + E (balance/reset)
        Ctrl+Alt+Super+E { reset-window-height; }

        // Rotate/cycle - HYPER + R
        Ctrl+Alt+Super+R { focus-column-right-or-first; }


        // Consume or expel windows (Niri-specific feature)
        Ctrl+Alt+Super+Comma { consume-window-into-column; }
        Ctrl+Alt+Super+Period { expel-window-from-column; }

        Ctrl+Alt+Super+BracketLeft  { consume-or-expel-window-left; }
        Ctrl+Alt+Super+BracketRight { consume-or-expel-window-right; }

        Ctrl+Alt+Super+WheelScrollDown      cooldown-ms=150 { focus-workspace-down; }
        Ctrl+Alt+Super+WheelScrollUp        cooldown-ms=150 { focus-workspace-up; }
        Ctrl+Alt+Super+Shift+WheelScrollDown cooldown-ms=150 { move-column-to-workspace-down; }
        Ctrl+Alt+Super+Shift+WheelScrollUp   cooldown-ms=150 { move-column-to-workspace-up; }

        Ctrl+Alt+Super+WheelScrollRight      { focus-column-right; }
        Ctrl+Alt+Super+WheelScrollLeft       { focus-column-left; }
        Ctrl+Alt+Super+Shift+WheelScrollRight { move-column-right; }
        Ctrl+Alt+Super+Shift+WheelScrollLeft  { move-column-left; }

        // ===== Additional useful bindings (using Super key for compatibility) =====

        // Application launcher - Super + D
        Super+Space { spawn "fuzzel"; }

        // Browser - Super + B
        Super+B { spawn "firefox"; }

        // File manager - Super + E
        Super+E { spawn "thunar"; }

        // Lock screen - Super + Escape
        Super+Escape { spawn "swaylock"; }

        // Screenshot - Print key
        Print { screenshot; }
        Ctrl+Print { screenshot-screen; }
        Alt+Print { screenshot-window; }

        // Quit Niri - Super + Shift + E
        Super+Shift+E { quit; }

        // Power off monitors - Super + Shift + P
        Super+Shift+P { power-off-monitors; }

        // Volume controls (if you have media keys)
        XF86AudioRaiseVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+ -l 1.0"; }
        XF86AudioLowerVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-"; }
        XF86AudioMute        allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"; }
        XF86AudioMicMute     allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"; }

        // Example media keys mapping using playerctl.
        XF86AudioPlay        allow-when-locked=true { spawn-sh "playerctl play-pause"; }
        XF86AudioStop        allow-when-locked=true { spawn-sh "playerctl stop"; }
        XF86AudioPrev        allow-when-locked=true { spawn-sh "playerctl previous"; }
        XF86AudioNext        allow-when-locked=true { spawn-sh "playerctl next"; }

        // Brightness controls (if you have media keys)
        XF86MonBrightnessUp { spawn "brightnessctl" "set" "10%+"; }
        XF86MonBrightnessDown { spawn "brightnessctl" "set" "10%-"; }


        // Resize mode toggle
        Super+R { switch-preset-column-width; }

    }

    window-rule {
        geometry-corner-radius 12
        clip-to-geometry true
    }

    // Debug settings
    debug {
        // Uncomment for troubleshooting
        // render-drm-device "/dev/dri/renderD128"
    }
  '';

  # Additional packages needed for Niri
  home.packages = with pkgs; [
    # Waybar for status bar
    waybar

    # Mako for notifications
    mako

    # Screenshot utilities (already in system, but good to have)
    grim
    slurp

    # Clipboard manager
    wl-clipboard

    # Optional: brightness control
    brightnessctl
  ];

  # Waybar configuration (reuse from Hyprland config)
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 30;

        modules-left = [
          "custom/logo"
          "clock"
        ];
        modules-center = [ ];
        modules-right = [
          "pulseaudio"
          "network"
          "cpu"
          "memory"
          "battery"
          "tray"
        ];

        "custom/logo" = {
          format = " ";
          tooltip = false;
        };

        "clock" = {
          format = "{:%H:%M}";
          format-alt = "{:%A, %B %d, %Y (%R)}";
          tooltip-format = "<tt><small>{calendar}</small></tt>";
        };

        "cpu" = {
          format = "  {usage}%";
          tooltip = false;
        };

        "memory" = {
          format = "  {}%";
        };

        "battery" = {
          format = "{icon}  {capacity}%";
          format-charging = "  {capacity}%";
          format-plugged = "  {capacity}%";
          format-icons = [
            ""
            ""
            ""
            ""
            ""
          ];
        };

        "network" = {
          format-wifi = "  {essid}";
          format-ethernet = "  {ifname}";
          format-disconnected = "⚠  Disconnected";
          tooltip-format = "{ifname}: {ipaddr}/{cidr}";
        };

        "pulseaudio" = {
          format = "{icon}  {volume}%";
          format-muted = "  Muted";
          format-icons = {
            default = [
              ""
              ""
              ""
            ];
          };
          on-click = "pavucontrol";
        };

        "tray" = {
          icon-size = 16;
          spacing = 10;
        };
      };
    };

    style = ''
      * {
        border: none;
        border-radius: 0;
        font-family: "JetBrainsMono Nerd Font";
        font-size: 13px;
        min-height: 0;
      }

      window#waybar {
        background: rgba(30, 30, 46, 0.9);
        color: #cdd6f4;
      }

      #workspaces button {
        padding: 0 8px;
        background: transparent;
        color: #cdd6f4;
      }

      #workspaces button.active {
        background: #89b4fa;
        color: #1e1e2e;
      }

      #workspaces button:hover {
        background: #45475a;
      }

      #clock,
      #battery,
      #cpu,
      #memory,
      #network,
      #pulseaudio,
      #tray,
      #custom-logo {
        padding: 0 10px;
        margin: 0 2px;
      }

      #battery.charging {
        color: #a6e3a1;
      }

      #battery.warning:not(.charging) {
        color: #f9e2af;
      }

      #battery.critical:not(.charging) {
        color: #f38ba8;
      }
    '';
  };

  # Mako notification daemon
  services.mako = {
    enable = true;
    settings = {
      background-color = "#1e1e2e";
      text-color = "#cdd6f4";
      border-color = "#89b4fa";
      border-radius = 8;
      border-size = 2;
      default-timeout = 5000;
    };
  };
}
