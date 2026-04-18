{
  lib,
  inputs,
  config,
  modulesPath,
  profiles,
  globals,
  pkgs,
  ...
}:
{
  # Backup NAS/storage server
  imports = with profiles; [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disk-config.nix
    ./hw.nix
    ./atticd.nix
    ./db.nix
    ./net.nix
    "${inputs.nixpkgs-forgejo-runner}/nixos/modules/services/continuous-integration/forgejo-runner.nix"

    nixos
    zfs
    impermanence
    hardware
    services.consul-client
    auto-update
  ];

  meta.usenftables = false;

  networking.hostId = "40f61b93";

  globals.nebula.mesh.hosts.demeter = {
    id = 3;
  };

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
  ];

  services.forgejo.runner.instances.homelab = {
    enable = true;
    name = config.node.name;
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
          config.age.secrets.nix-cache-netrc.path
        ];
        options = lib.concatStringsSep " " [
          "-v /nix/store:/nix/store:ro"
          "-v /nix/var/nix/daemon-socket:/nix/var/nix/daemon-socket"
          "-v /run/current-system/sw/bin/nix:/usr/local/bin/nix"
          "-v ${pkgs.sops}/bin/sops:/usr/local/bin/sops"
          "-v ${pkgs.attic-client}/bin/attic-client:/usr/local/bin/attic-client"
          "-v /etc/nix/ci-nix.conf:/etc/nix/nix.conf:ro"
          "-v ${config.age.secrets.nix-cache-netrc.path}:${config.age.secrets.nix-cache-netrc.path}:ro"
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

  services.nomad-client = {
    enable = true;
    isMicrovm = false;
    macvlanMaster = "serverBr";
  };

  meta.vector.enable = true;
  meta.telegraf.enable = true;

  system.stateVersion = "24.11";
}
