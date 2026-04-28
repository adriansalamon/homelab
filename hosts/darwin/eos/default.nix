{
  inputs,
  pkgs,
  profiles,
  globals,
  ...
}:
{
  imports = [
    ./backrest.nix
    ./paneru.nix
    profiles.darwin
  ];

  globals.nebula.mesh.hosts.eos = {
    id = 4610;
    groups = [ "network-admin" ];
    monitor = false;

    config.settings.tun.unsafe_routes = [
      {
        route = globals.sites.olympus.vlans.management.cidrv4;
        via = globals.nebula.mesh.hosts.athena.ipv4;
      }
    ];
  };

  system.defaults = {
    NSGlobalDomain = {
      ApplePressAndHoldEnabled = false; # enable key repeat (essential for vim)
      InitialKeyRepeat = 15; # delay before repeat starts (lower = faster)
      KeyRepeat = 2; # repeat rate (lower = faster)
    };

    dock = {
      autohide = true;
      autohide-delay = 0.0;
      autohide-time-modifier = 0.0;
      show-recents = false;
    };

    finder = {
      ShowPathbar = true;
      ShowStatusBar = true;
    };
  };

  launchd.user.agents.colima = {
    serviceConfig = {
      ProgramArguments = [
        "${pkgs.colima}/bin/colima"
        "start"
        "--foreground"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/tmp/colima.log";
      StandardErrorPath = "/tmp/colima.log";
      EnvironmentVariables = {
        PATH = "${pkgs.colima}/bin:${pkgs.docker}/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      };
    };
  };

  launchd.user.agents.raycast = {
    serviceConfig = {
      ProgramArguments = [ "${pkgs.raycast}/Applications/Raycast.app/Contents/MacOS/Raycast" ];
      RunAtLoad = true;
      KeepAlive = false;
    };
  };

  environment.systemPackages = with pkgs; [
    raycast
    backrest
    bat
    colima
    docker
    docker-compose
    fd
    ripgrep
    age-plugin-yubikey
    alejandra
    attic-client
    atuin
    btop
    coreutils
    fzf
    git
    ghostty-bin
    inputs.agenix-rekey.packages."${stdenv.hostPlatform.system}".default
    inputs.deploy-rs.packages."${stdenv.hostPlatform.system}".default
    jq
    lazygit
    nil
    nixd
    nixfmt
    nebula
    beam.packages.erlang_27.elixir
    nodejs
    nomad_2_0
    rage
    restic
    tldr
    vault-bin
    uv
    yq
  ];

  fonts.packages = [ pkgs.nerd-fonts.lilex ];

  homebrew = {
    enable = true;

    brews = [
      "ollama"
    ];

    casks = [
      "betterdisplay"
      "claude-code"
      "firefox"
      "hiddenbar"
      "karabiner-elements"
      "spotify"
      "ukelele"
      "unnaturalscrollwheels"
      "zed"
    ];
  };

  security.pam.services.sudo_local.touchIdAuth = true;

  system.stateVersion = 5;
}
