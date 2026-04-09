{ pkgs, ... }:
{
  imports = [
    ../common/shell.nix
    ../common/nvim.nix
    ./niri.nix
    ./desktop.nix
  ];

  # Allow unfree packages in home-manager
  nixpkgs.config.allowUnfree = true;

  home = {
    username = "asalamon";
    homeDirectory = "/home/asalamon";

    # Desktop-specific packages
    packages = with pkgs; [
      # Development
      rustup
      consul
      vault-bin
      sops

      # Desktop tools
      htop
      ripgrep
      fd
      bat
      eza

      # GUI applications (that aren't already in the desktop profile)
      vscode
      discord
      spotify

      # Screenshot tools (already installed system-wide but good to have)
      grim
      slurp
      wl-clipboard
    ];

    # Session variables
    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
  };

  # Git configuration
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Adrian Salamon";
        email = "adr.salamon@gmail.com";
      };

      init.defaultBranch = "main";
      pull.rebase = true;
      core.editor = "nvim";
    };
  };

  # Enable SSH agent
  services.ssh-agent.enable = true;

  # XDG user directories
  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
      setSessionVariables = true; # Explicitly set for compatibility
      desktop = "$HOME/Desktop";
      documents = "$HOME/Documents";
      download = "$HOME/Downloads";
      music = "$HOME/Music";
      pictures = "$HOME/Pictures";
      videos = "$HOME/Videos";
    };
  };

  # Impermanence - persist home directory files
  # Note: Path should NOT include the home directory, just the base persist path
  home.persistence."/persist" = {
    directories = [
      "Documents"
      "Downloads"
      "Music"
      "Pictures"
      "Videos"
      "Projects"
      ".ssh"
      ".local/share/atuin"
      ".local/share/direnv"
      ".cargo"
      ".rustup"
      ".config/discord"
      ".config/spotify"
      ".mozilla"
      ".vscode"
    ];

    files = [
      ".zsh_history"
    ];
  };
}
