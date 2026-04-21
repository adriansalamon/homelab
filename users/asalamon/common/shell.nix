{ pkgs, config, ... }:
{
  # Shared shell configuration for both macOS and Linux
  programs = {
    fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    starship = {
      enable = true;
      settings = {
        gcloud = {
          detect_env_vars = [ "GOOGLE_CLOUD" ];
        };
        aws = {
          disabled = true;
        };
      };
    };

    direnv = {
      enable = true;
      enableZshIntegration = true;
      # FIXME: Remove this override once the fix lands in nixpkgs-unstable
      # https://github.com/naitokosuke/dotfiles/pull/283
      # https://github.com/NixOS/nixpkgs/issues/504092
      # https://github.com/NixOS/nixpkgs/pull/502769
      package = pkgs.direnv.overrideAttrs (old: {
        env = (old.env or { }) // {
          CGO_ENABLED = 1;
        };
      });
    };

    atuin = {
      enable = true;
      enableZshIntegration = true;
    };

    tmux = {
      enable = true;
      terminal = "tmux-256color";
      historyLimit = 50000;
      keyMode = "vi";
      mouse = true;
      prefix = "C-a";
      escapeTime = 0;
    };

    zsh = {
      enable = true;
      dotDir = "${config.xdg.configHome}/zsh";  # Use XDG config directory

      zplug = {
        enable = true;
        plugins = [
          { name = "zsh-users/zsh-autosuggestions"; }
          { name = "zsh-users/zsh-syntax-highlighting"; }
          { name = "zsh-users/zsh-completions"; }
          { name = "zsh-users/zsh-history-substring-search"; }
          { name = "unixorn/warhol.plugin.zsh"; }
        ];
      };

      shellAliases = {
        la = "ls --color -lha";
      };

      initContent = ''
        export PATH="$HOME/.cargo/bin:$PATH"
      '';
    };
  };
}
