{
  self,
  config,
  pkgs,
  lib,
  ...
}:

let
  inherit (lib)
    optionals
    types
    mkEnableOption
    mkOption
    mkIf
    ;

  cfg = config.services.rift;

  toml = pkgs.formats.toml { };

  configFile = if cfg.config != { } then toml.generate "rift.toml" cfg.config else cfg.configFile;
in
{
  options.services.rift = {
    enable = mkEnableOption "Enable rift window manager service";

    package = mkOption {
      type = types.package;
      default = self.packages.${pkgs.system}.default;
      description = "rift (not rift-cli) package to use";
    };

    config = mkOption {
      type = toml.type;
      description = "Configuration settings for rift. Also accepts paths (string or path type) to a config file.";
      default = { };
    };

    configFile = mkOption {
      type = types.nullOr types.path;
      description = "Toml config file";
      default = null;
    };
  };

  config = mkIf cfg.enable {
    launchd.user.agents.rift = {
      managedBy = "services.rift.enable";
      serviceConfig = {
        Label = "git.acsandmann.rift";
        ProgramArguments = [
          "${cfg.package}/bin/rift"
        ]
        ++ optionals (configFile != null) [
          "--config"
          "${lib.escapeShellArg configFile}"
        ];
        EnvironmentVariables = {
          RUST_LOG = "error,warn,info";
          PATH = "${cfg.package}/bin:${config.environment.systemPath}";
        };
        RunAtLoad = true;
        KeepAlive = {
          SuccessfulExit = false;
          Crashed = true;
        };

        Nice = -20;
        LimitLoadToSessionType = "Aqua";
        # todo add _{user} to log file name
        StandardOutPath = "/tmp/rift.out.log";
        StandardErrorPath = "/tmp/rift.err.log";
      };
    };
  };
}
