{ pkgs, ... }:
let
  builtInKeyboardCondition = {
    type = "device_if";
    identifiers = [ { is_built_in_keyboard = true; } ];
  };

  # Caps lock → escape when tapped, hyper (right_ctrl+right_opt+right_cmd)
  # when held. Mirrors ZMK external keyboard behaviour.
  capsLockRule = {
    description = "Caps Lock: escape on tap, hyper on hold (built-in keyboard only)";
    manipulators = [
      {
        type = "basic";
        from = {
          key_code = "caps_lock";
          modifiers.optional = [ "any" ];
        };
        to = [
          {
            key_code = "right_control";
            modifiers = [
              "right_option"
              "right_command"
            ];
          }
        ];
        to_if_alone = [ { key_code = "escape"; } ];
        conditions = [ builtInKeyboardCondition ];
      }
    ];
  };

  karabinerConfig = {
    global.show_in_menu_bar = false;
    profiles = [
      {
        name = "Default profile";
        selected = true;
        complex_modifications.rules = [ capsLockRule ];
      }
    ];
  };

  karabinerJson = pkgs.writeText "karabiner.json" (builtins.toJSON karabinerConfig);

  # Karabiner watches the parent directory — symlinking only karabiner.json
  # triggers a warning, so we expose the whole directory from the store.
  karabinerConfigDir = pkgs.runCommandLocal "karabiner-config" { } ''
    mkdir -p "$out/assets/complex_modifications"
    cp ${karabinerJson} "$out/karabiner.json"
  '';
in
{
  home.file.".config/karabiner".source = karabinerConfigDir;

  # Back up any existing mutable karabiner config before home-manager takes over.
  home.activation.karabinerConfigMigration = {
    before = [ "checkLinkTargets" ];
    after = [ ];
    data = ''
      target="$HOME/.config/karabiner"
      backup="$HOME/.config/karabiner.pre-declarative"

      if [ -e "$target" ] && [ ! -L "$target" ]; then
        if [ -e "$backup" ]; then
          echo "Refusing to replace $target because $backup already exists." >&2
          exit 1
        fi
        $DRY_RUN_CMD mv "$target" "$backup"
      fi
    '';
  };

  # Kick karabiner's console user server so changes take effect immediately.
  home.activation.karabinerReload = {
    before = [ ];
    after = [ "writeBoundary" ];
    data = ''
      if /bin/launchctl print "gui/$UID/org.pqrs.service.agent.karabiner_console_user_server" >/dev/null 2>&1; then
        $DRY_RUN_CMD /bin/launchctl kickstart -k "gui/$UID/org.pqrs.service.agent.karabiner_console_user_server"
      elif /bin/launchctl print "gui/$UID/org.pqrs.karabiner.karabiner_console_user_server" >/dev/null 2>&1; then
        $DRY_RUN_CMD /bin/launchctl kickstart -k "gui/$UID/org.pqrs.karabiner.karabiner_console_user_server"
      fi
    '';
  };
}
