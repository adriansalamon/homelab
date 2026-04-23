{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.prometheus.exporters.rustic;
in
{

  options.services.prometheus.exporters.rustic = {
    enable = lib.mkEnableOption "rustic-exporter";

    package = lib.mkPackageOption pkgs "rustic-exporter" { };

    host = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
    };

    settings = lib.mkOption {
      inherit ((pkgs.formats.toml { })) type;
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services."prometheus-rustic-exporter" = {
      description = "Prometheus exporter for restic/rustic repos";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      path = [
        config.programs.ssh.package
      ];

      serviceConfig =
        let
          format = pkgs.formats.toml { };
          configFile = format.generate "config.toml" cfg.settings;
        in
        {
          ExecStart = "${lib.getExe cfg.package} --config ${configFile} --host ${toString cfg.host} --port ${toString cfg.port}";
          Restart = "always";
          PrivateTmp = true;
          DynamicUser = true;

          # Allow unit to read all files in the system
          AmbientCapabilities = [ "CAP_DAC_READ_SEARCH" ];
        };

      unitConfig = {
        StartLimitIntervalSec = 10;
        StartLimitBurst = 5;
      };
    };
  };
}
