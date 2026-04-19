{
  inputs,
  config,
  globals,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    "${inputs.nixpkgs-forgejo-runner}/nixos/modules/services/continuous-integration/forgejo-runner.nix"
  ];

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  age.secrets.forgejo-runner-token = {
    rekeyFile = config.node.secretsDir + "/forgejo-runner-token.age";
    mode = "400";
  };

  environment.persistence."/state".directories = [
    {
      directory = "/var/lib/forgejo-runner";
      user = "root";
      group = "root";
      mode = "0755";
    }
    {
      directory = "/var/cache/nix-eval";
      user = "root";
      group = "root";
      mode = "0755";
    }
  ];

  services.forgejo.runner.instances.docker = {
    enable = true;
    name = "${config.node.name}";
    url = "https://forgejo.${globals.domains.main}";
    tokenFile = config.age.secrets.forgejo-runner-token.path;
    labels = [
      "ubuntu-latest:docker://ghcr.io/catthehacker/ubuntu:act-latest"
      "runner-latest:docker://ghcr.io/catthehacker/ubuntu:runner-latest"
    ];
    settings = {
      log = {
        level = "info";
      };

      runner = {
        # Where to store the registration result.
        file = ".runner";
        # Execute how many tasks concurrently at the same time.
        capacity = 5;
        envs = { };
        timeout = "3h";
        shutdown_timeout = "5m";
        insecure = false;
        fetch_timeout = "5s";
        fetch_interval = "2s";
        report_interval = "1s";
      };
      cache = {
        enabled = true;
        dir = "/var/lib/forgejo-runner/cache";
      };

      container = {
        network = "bridge";
        privileged = true;
        docker_host = "automount";
        valid_volumes = [ ];
        options = lib.concatStringsSep " " [ ];
      };
    };
  };

  services.forgejo.runner.instances.nix = {
    enable = true;
    name = "nix_${config.node.name}";
    url = "https://forgejo.${globals.domains.main}";
    tokenFile = config.age.secrets.forgejo-runner-token.path;
    labels = [
      "nix:docker://ghcr.io/catthehacker/ubuntu:act-latest"
    ];
    settings = {
      log = {
        level = "info";
      };

      runner = {
        # Where to store the registration result.
        file = ".runner";
        # Execute how many tasks concurrently at the same time.
        capacity = 2;
        envs = { };
        timeout = "3h";
        shutdown_timeout = "5m";
        insecure = false;
        fetch_timeout = "5s";
        fetch_interval = "2s";
        report_interval = "1s";
      };
      cache = {
        enabled = true;
        dir = "/var/lib/forgejo-runner/cache";
      };

      container = {
        network = "bridge";
        privileged = true;
        docker_host = "automount";
        valid_volumes = [
          "/nix/store"
          "/nix/var/nix/daemon-socket"
          "/run/current-system/sw/bin/nix"
          "/etc/nix/ci-nix.conf"
          "/var/cache/nix-eval"
          "${pkgs.sops}/bin/sops"
          "${pkgs.attic-client}/bin/attic"
          config.age.secrets.nix-cache-netrc.path
        ];
        options = lib.concatStringsSep " " [
          "-v /nix/store:/nix/store:ro"
          "-v /nix/var/nix/daemon-socket:/nix/var/nix/daemon-socket"
          "-v /run/current-system/sw/bin/nix:/usr/local/bin/nix:ro"
          "-v ${pkgs.sops}/bin/sops:/usr/local/bin/sops:ro"
          "-v ${pkgs.attic-client}/bin/attic:/usr/local/bin/attic:ro"
          "-v /etc/nix/ci-nix.conf:/etc/nix/nix.conf:ro"
          "-v ${config.age.secrets.nix-cache-netrc.path}:${config.age.secrets.nix-cache-netrc.path}:ro"
          "-v /var/cache/nix-eval:/root/.cache/nix"
          "-e NIX_REMOTE=daemon"
        ];
      };
    };
  };

  environment.etc."nix/ci-nix.conf".text = ''
    experimental-features = nix-command flakes
    substituters = https://nix-cache.${globals.domains.main}/homelab https://cache.nixos.org
    trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= homelab:leKffLkOCSfX8pPGaQltduLxJNNVmG5oGPt6w3fH4t0=
    netrc-file = ${config.age.secrets.nix-cache-netrc.path}
    always-allow-substitutes = true
    allow-import-from-derivation = false
    extra-platforms = aarch64-linux
  '';
}
