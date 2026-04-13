{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkPackageOption
    mkOption
    types
    literalExpression
    mkIf
    escapeShellArgs
    optional
    concatMap
    mkDefault
    ;

  cfg = config.services.vault-server;
  format = pkgs.formats.json { };
in
{
  ##### interface
  options = {
    services.vault-server = {
      enable = mkEnableOption "Vault server daemon";

      package = mkPackageOption pkgs "vault" { };

      dev = mkOption {
        type = types.bool;
        default = false;
        description = ''
          In this mode, Vault runs in-memory and starts unsealed.
          This option is not meant for production but for development and testing.
        '';
      };

      devRootTokenID = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Initial root token. This only applies when {option}`services.vault.dev` is true.
        '';
      };
      storageBackend = mkOption {
        type = types.enum [
          "inmem"
          "file"
          "consul"
          "zookeeper"
          "s3"
          "azure"
          "dynamodb"
          "etcd"
          "mssql"
          "mysql"
          "postgresql"
          "swift"
          "gcs"
          "raft"
        ];
        default = "inmem";
        description = ''
          The name of the type of storage backend.

          Note: In this JSON-based module, this option is primarily used to declare
          systemd dependencies (like waiting for `consul.service`). You must still
          configure the actual storage parameters in {option}`services.vault-server.settings`
          or via {option}`services.vault.extraSettingsPaths`.
        '';
      };

      extraSettingsPaths = mkOption {
        type = types.listOf types.path;
        default = [ ];
        description = ''
          Configuration files to load besides the generated JSON one.
          This can be used to avoid putting credentials in the Nix store,
          which can be read by any user.

          Each path can point to a JSON- or HCL-formatted file, or a directory
          to be scanned for files with `.hcl` or `.json` extensions.
        '';
        example = literalExpression ''
          [ "/run/keys/vault-secrets.json" "/etc/vault.d/" ]
        '';
      };

      environmentFiles = mkOption {
        type = types.listOf types.path;
        default = [ ];
        description = ''
          Environment files to load for Vault.
        '';
        example = literalExpression ''
          [ "/run/keys/vault-env" ]
        '';
      };

      settings = mkOption {
        type = format.type;
        default = { };
        description = ''
          Configuration for Vault. See the [documentation](https://developer.hashicorp.com/vault/docs/configuration)
          for supported values.

          Confidential values should not be specified here because this option's
          value is written to the Nix store, which is publicly readable.
          Provide credentials and such in a separate file using
          {option}`services.vault.extraSettingsPaths`.
        '';
        example = literalExpression ''
          {
            listener.tcp = {
              address = "127.0.0.1:8200";
              tls_disable = true;
            };
            storage.file = {
              path = "/var/lib/vault";
            };
            telemetry = {
              prometheus_retention_time = "30s";
              disable_hostname = true;
            };
          }
        '';
      };

      pluginDirectory = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          Directory containing Vault plugins. This will be set as the
          plugin_directory configuration option. The directory cannot be
          a symbolic link, but the files within it can be.
        '';
        example = literalExpression ''
          pkgs.vault-plugins
        '';
      };
    };
  };

  ##### implementation
  config = mkIf cfg.enable {
    environment = {
      systemPackages = [ cfg.package ];
    };
    services.vault-server.settings = {
      storage.${cfg.storageBackend} = mkDefault { };
      plugin_directory = mkIf (cfg.pluginDirectory != null) (toString cfg.pluginDirectory);
    };

    # Use dynamically allocated system user instead of hardcoded ids
    users.users.vault = {
      name = "vault";
      group = "vault";
      isSystemUser = true;
      description = "Vault daemon user";
    };
    users.groups.vault = { };

    systemd.services.vault = {
      description = "Vault server daemon";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
      ]
      ++ lib.optional (config.services.consul.enable && cfg.storageBackend == "consul") "consul.service";
      wants = [
        "network-online.target"
      ]
      ++ lib.optional (config.services.consul.enable && cfg.storageBackend == "consul") "consul.service";

      # Do not restart on "nixos-rebuild switch". It would seal the storage and disrupt clients.
      restartIfChanged = false;

      serviceConfig = {
        User = "vault";
        Group = "vault";
        ExecStart =
          let
            args = escapeShellArgs (
              optional cfg.dev "-dev"
              ++ optional (cfg.dev && cfg.devRootTokenID != null) "-dev-root-token-id=${cfg.devRootTokenID}"
              ++ [ "-config=${format.generate "vault.json" cfg.settings}" ]
              ++ (concatMap (path: " -config=${path}") cfg.extraSettingsPaths)
            );
          in
          "${cfg.package}/bin/vault server ${args}";

        ExecReload = "${pkgs.coreutils}/bin/kill -SIGHUP $MAINPID";

        # This acts as a replacement for systemd.tmpfiles.rules
        # It ensures /var/lib/vault exists and is owned by the vault user.
        StateDirectory = "vault";

        # In `dev` mode vault will put its token here
        Environment = (optional cfg.dev "HOME=/var/lib/vault");
        EnvironmentFile = cfg.environmentFiles;

        # Hardening
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectSystem = "full";
        ProtectHome = "read-only";
        AmbientCapabilities = "cap_ipc_lock";
        NoNewPrivileges = true;
        LimitCORE = 0;
        KillSignal = "SIGINT";
        TimeoutStopSec = "30s";
        Restart = "on-failure";
      };

      unitConfig = {
        StartLimitIntervalSec = 60;
        StartLimitBurst = 3;
      };
    };
  };
}
