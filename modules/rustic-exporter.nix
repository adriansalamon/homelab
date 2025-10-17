{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.prometheus.exporters.rustic;
  defaultUser = "rustic-exporter";
in
{

  options.services.prometheus.exporters.rustic = {
    enable = lib.mkEnableOption "rustic-exporter";

    package = lib.mkPackageOption pkgs "rustic-exporter" { };

    user = lib.mkOption {
      type = lib.types.str;
      default = defaultUser;
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
    };

    settings = lib.mkOption {
      type = (pkgs.formats.toml { }).type;
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    users = lib.mkIf (cfg.user != defaultUser) {
      groups.rustic-exporter = { };
      users.${defaultUser} = {
        isSystemUser = true;
        group = "rustic-exporter";
      };
    };

    systemd.services."prometheus-rustic-exporter" = {
      description = "Prometheus exporter for restic/rustic repos";
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
          User = cfg.user;
          PrivateTmp = true;
        };
      unitConfig = {
        StartLimitIntervalSec = 10;
        StartLimitBurst = 5;
      };
    };
  };
}
