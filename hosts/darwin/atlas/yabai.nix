{ pkgs, ... }:
let
  script = pkgs.writeText "iterm.script" ''
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
  services.yabai = {
    enable = true;
    enableScriptingAddition = true;
    extraConfig = ''
      # scripting addition
      yabai -m signal --add event=dock_did_restart action="sudo yabai --load-sa"
      sudo yabai --load-sa

      # default layout (can be bsp, stack, or float)
      yabai -m config layout bsp
      yabai -m config auto_balance on

      # New window spawns to the right if vertical split, or bottom if horizontal split
      yabai -m config window_placement second_child

      # padding set to 12px
      yabai -m config top_padding 12
      yabai -m config bottom_padding 12
      yabai -m config left_padding 12
      yabai -m config right_padding 12
      yabai -m config window_gap 12

      # center mouse on window with focus
      #yabai -m config mouse_follows_focus off

      # focus follows mouse
      yabai -m config focus_follows_mouse autoraise

      # modifier for clicking and dragging with mouse
      yabai -m config mouse_modifier alt
      # set modifier + left-click drag to move window
      yabai -m config mouse_action1 move
      # set modifier + right-click drag to resize window
      yabai -m config mouse_action2 resize


      # when window is dropped in center of another window, swap them (on edges it will split it)
      yabai -m mouse_drop_action swap
      yabai -m rule --add app="^System Settings$" manage=off
      yabai -m rule --add app="^app_gma3$" manage=off
      yabai -m rule --add app="^Fusion$" manage=off
      yabai -m rule --add app="^Autodesk Fusion 360$" manage=off

      yabai -m rule --apply
    '';
  };

  services.skhd = {
    enable = true;
    skhdConfig = ''
      # Open new terminal
      rcmd + rshift + ralt + rctrl - return : osascript ${script}

      # close window
      rcmd + rshift + ralt + rctrl - q : yabai -m window --close

      # change window focus within space
      rcmd + rshift + ralt + rctrl - j : yabai -m window --focus south
      rcmd + rshift + ralt + rctrl - k : yabai -m window --focus north
      rcmd + rshift + ralt + rctrl - h : yabai -m window --focus west
      rcmd + rshift + ralt + rctrl - l : yabai -m window --focus east

      #change focus between external displays (left and right)
      rcmd + rshift + ralt + rctrl - s: yabai -m display --focus west
      rcmd + rshift + ralt + rctrl - g: yabai -m display --focus east

      # rotate layout clockwise
      hyper - r : yabai -m space --rotate 270

      # flip along y-axis
      hyper - y : yabai -m space --mirror y-a=xis
      # flip along x-axis
      hyper - x : yabai -m space --mirror x-axis

      # toggle window float
      hyper - t : yabai -m window --toggle float --grid 4:4:1:1:2:2

      # maximize a window
      hyper - m : yabai -m window --toggle zoom-fullscreen

      # balance out tree of windows (resize to occupy same area)
      hyper - e : yabai -m space --balance

      # swap windows
      rcmd + rshift + ralt + rctrl + lshift - j : yabai -m window --swap south
      rcmd + rshift + ralt + rctrl + lshift - k : yabai -m window --swap north
      rcmd + rshift + ralt + rctrl + lshift - h : yabai -m window --swap west
      rcmd + rshift + ralt + rctrl + lshift - l : yabai -m window --swap east

      # move window to display left and right
      rcmd + rshift + ralt + rctrl + lshift - s : yabai -m window --display west; yabai -m display --focus west;
      rcmd + rshift + ralt + rctrl + lshift - g : yabai -m window --display east; yabai -m display --focus east;

      #move window to prev and next space
      rcmd + rshift + ralt + rctrl + lshift - p : yabai -m window --space prev;
      rcmd + rshift + ralt + rctrl + lshift - n : yabai -m window --space next;

      # move window to space
      rcmd + rshift + ralt + rctrl + lshift - 1 : yabai -m window --space 1;
      rcmd + rshift + ralt + rctrl + lshift - 2 : yabai -m window --space 2;
      rcmd + rshift + ralt + rctrl + lshift - 3 : yabai -m window --space 3;
      rcmd + rshift + ralt + rctrl + lshift - 4 : yabai -m window --space 4;
      rcmd + rshift + ralt + rctrl + lshift - 5 : yabai -m window --space 5;
      rcmd + rshift + ralt + rctrl + lshift - 6 : yabai -m window --space 6;
      rcmd + rshift + ralt + rctrl + lshift - 7 : yabai -m window --space 7;
      rcmd + rshift + ralt + rctrl + lshift - 8 : yabai -m window --space 8;
      rcmd + rshift + ralt + rctrl + lshift - 9 : yabai -m window --space 9;

      # change focus between prev and next space
      rcmd + rshift + ralt + rctrl - p : yabai -m space --focus prev
      rcmd + rshift + ralt + rctrl - n : yabai -m space --focus next

      # change focus to space
      rcmd + rshift + ralt + rctrl - 1 : yabai -m space --focus 1;
      rcmd + rshift + ralt + rctrl - 2 : yabai -m space --focus 2;
      rcmd + rshift + ralt + rctrl - 3 : yabai -m space --focus 3;
      rcmd + rshift + ralt + rctrl - 4 : yabai -m space --focus 4;
      rcmd + rshift + ralt + rctrl - 5 : yabai -m space --focus 5;
      rcmd + rshift + ralt + rctrl - 6 : yabai -m space --focus 6;
      rcmd + rshift + ralt + rctrl - 7 : yabai -m space --focus 7;
      rcmd + rshift + ralt + rctrl - 8 : yabai -m space --focus 8;
      rcmd + rshift + ralt + rctrl - 9 : yabai -m space --focus 9;

      # stop/start/restart yabai
      # ctrl + alt - q : brew services stop yabai
      # ctrl + alt - s : brew services start yabai
      # ctrl + alt - r : brew services restart yabai
    '';
  };
}
