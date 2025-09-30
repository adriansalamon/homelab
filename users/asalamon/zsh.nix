{ ... }:
{
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
    };

    atuin = {
      enable = true;
      enableZshIntegration = true;
    };

    zsh = {
      enable = true;

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
