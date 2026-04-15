{
  inputs,
  pkgs,
  globals,
  profiles,
  ...
}:
{

  imports = [
    ./paneru.nix

    profiles.darwin
  ];

  globals.nebula.mesh.hosts.atlas = {
    id = 4609;
    groups = [ "network-admin" ];

    config.settings.tun.unsafe_routes = [
      {
        route = globals.sites.olympus.vlans.management.cidrv4;
        via = globals.nebula.mesh.hosts.athena.ipv4;
      }
    ];
  };

  environment.systemPackages = with pkgs; [
    age-plugin-yubikey
    alejandra
    attic-client
    atuin
    backrest
    btop
    cook-cli
    coreutils
    fzf
    git
    git-agecrypt
    gleam
    inputs.agenix-rekey.packages."${stdenv.hostPlatform.system}".default
    inputs.deploy-rs.packages."${stdenv.hostPlatform.system}".default
    iperf3
    lazygit
    nebula
    nebula
    nil
    nixd
    nixfmt
    nodejs
    nomad_1_11
    rage
    restic
    tldr
    typst
    vim
    yubikey-personalization
    uv
  ];

  launchd.user.agents.backrest = {
    serviceConfig.ProgramArguments = [ "${pkgs.backrest}/bin/backrest" ];
    serviceConfig.KeepAlive = true;
  };

  # Homebrew configuration
  homebrew = {
    enable = true;

    # Don't auto-update on every activation (you can update manually)
    onActivation.autoUpdate = true;
    onActivation.cleanup = "uninstall";

    # Taps (third-party repositories)
    taps = [
      "acsandmann/tap"
      "clojure/tools"
      "dart-lang/dart"
      "exolnet/deprecated"
      "gerlero/openfoam"
      "hashicorp/tap"
      "homebrew/services"
      "koekeishiya/formulae"
      "kreuzwerker/taps"
      "leoafarias/fvm"
      "nats-io/nats-tools"
      "omissis/go-jsonschema"
      "shivammathur/php"
      "stripe/stripe-cli"
      "theseal/ssh-askpass"
    ];

    # Formulae (CLI tools) - only top-level packages, not dependencies
    # TODO: Gradually migrate tools to Nix packages where appropriate
    brews = [
      "aircrack-ng"
      "ansible"
      "automake"
      "baobab"
      "bfg"
      "clang-format"
      "cloc"
      "clojure/tools/clojure"
      "cloudflared"
      "cocoapods"
      "composer"
      "cowsay"
      "dcraw"
      "deno"
      "docker-compose"
      "dos2unix"
      "dua-cli"
      "duc"
      "e2fsprogs"
      "elixir-ls"
      "fclones"
      "flyctl"
      "fontforge"
      "fortune"
      "gawk"
      "gdu"
      "gh"
      "git-filter-repo"
      "git-quick-stats"
      "glm"
      "gnucobol"
      "gobject-introspection"
      "gptfdisk"
      "guile"
      "hashcat"
      "htop"
      "hyperfine"
      "imapsync"
      "instalooter"
      "irssi"
      "jenv"
      "jq"
      "k6"
      "kreuzwerker/taps/m1-terraform-provider-helper"
      "lcdf-typetools"
      "leoafarias/fvm/fvm"
      "libmagic"
      "llvm"
      "llvm@12"
      "macchina"
      "mariadb"
      "minicom"
      "mole"
      "mpv"
      "nats-io/nats-tools/nats"
      "ncdu"
      "nghttp2"
      "ninja"
      "nlohmann-json"
      "nmap"
      "ollama"
      "omissis/go-jsonschema/go-jsonschema"
      "openjdk@17"
      "opentofu"
      "p7zip"
      "pandoc"
      "pipenv"
      "portaudio"
      "postgresql@14"
      "py3cairo"
      "pygments"
      "pyqt@5"
      "python-tk@3.11"
      "python-tk@3.13"
      "python@3.10"
      "python@3.8"
      "qt"
      "rclone"
      "rsync"
      "scc"
      "scipy"
      "sevenzip"
      "shivammathur/php/php@7.3"
      "shivammathur/php/php@7.4"
      "smartmontools"
      "snapcast"
      "sqlmap"
      "sshpass"
      "stripe/stripe-cli/stripe"
      "swi-prolog"
      "tccutil"
      "tesseract-lang"
      "theseal/ssh-askpass/ssh-askpass"
      "tmux"
      "transmission-cli"
      "utf8cpp"
      "vegeta"
      "wget"
      "yubico-piv-tool"
      "zbar"
    ];

    # Casks (GUI applications)
    casks = [
      "anaconda"
      "arduino-ide"
      "audacity"
      "balenaetcher"
      "calibre"
      "cmake-app"
      "claude-code"
      "discord"
      "docker-desktop"
      "dotnet-sdk"
      "dozer"
      "figma"
      "flutter"
      "font-hack-nerd-font"
      "gcloud-cli"
      "goland"
      "gpg-suite"
      "hiddenbar"
      "inkscape"
      "intellij-idea"
      "iterm2"
      "karabiner-elements"
      "keycastr"
      "kopiaui"
      "livebook"
      "mark-text"
      "mars"
      "microsoft-auto-update"
      "microsoft-office"
      "multipass"
      "ngrok"
      "notion"
      "obs"
      "obsidian"
      "openscad"
      "postman"
      "private-internet-access"
      "raspberry-pi-imager"
      "raycast"
      "rectangle"
      "rwts-pdfwriter"
      "slack"
      "spotify"
      "steam"
      "tailscale-app"
      "the-unarchiver"
      "transmission"
      "ukelele"
      "visual-studio-code"
      "vlc"
      "whisky"
      "wireshark-app"
      "xquartz"
      "zed"
      "zotero"
    ];
  };

  system.stateVersion = 5;
}
