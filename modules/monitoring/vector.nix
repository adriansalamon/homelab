{
  config,
  lib,
  ...
}:
let
  cfg = config.meta.vector;

in
{
  options.meta.vector = {
    enable = lib.mkEnableOption "Vector pushes logs to Loki";
  };

  config = lib.mkIf (cfg.enable) {
    age.secrets.vector-loki-basic-auth-password = {
      # we don't need this file on the server
      intermediary = true;

      generator = {
        tags = [ "loki-basic-auth" ];
        script = "alnum";
      };
    };

    # Loki can read secrets from json files, we create one
    age.secrets.vector-loki-auth-json = {
      generator = {
        dependencies = [ config.age.secrets.vector-loki-basic-auth-password ];
        tags = [ "loki-basic-auth-json" ];
        script =
          {
            pkgs,
            lib,
            decrypt,
            deps,
            ...
          }:
          let
            dep = lib.head deps;
            formatName = name: (builtins.replaceStrings [ ":" ] [ "/" ] (lib.escapeShellArg name));
          in
          ''
            username=${formatName dep.host}"+"${formatName dep.name}
            password=$(${decrypt} ${lib.escapeShellArg dep.file})
            echo {} | ${pkgs.jq}/bin/jq --arg password $password --arg username $username \
              '{username: $username, password: $password}'
          '';
      };

      owner = "vector";
      mode = "0400";
    };

    globals.loki-secrets = [ config.age.secrets.vector-loki-basic-auth-password ];

    services.vector = {
      enable = true;
      journaldAccess = true;

      settings = {
        # Accessable as "SECRET[basic-auth.<json key>]"
        secret.basic_auth = {
          type = "file";
          path = config.age.secrets.vector-loki-auth-json.path;
        };

        sources = {
          journald.type = "journald";
        };

        transforms = {
          parse_journald = {
            type = "remap";
            inputs = [ "journald" ];
            source = ''
              # Extract useful journald fields
              if exists(._SYSTEMD_UNIT) {
                .unit = ._SYSTEMD_UNIT
                del(._SYSTEMD_UNIT)
              } else {
                .unit = ._TRANSPORT
              }
              .priority = .PRIORITY

              del(.PRIORITY)

              # Normalize session-*.scope → session.scope
              if .unit != null && match(string!(.unit), r'^session-\d+\.scope$') {
                .unit = "session.scope"
              }

              .command = ._COMM
              del(._COMM)
            '';
          };
        };

        sinks = {
          loki = {
            type = "loki";
            inputs = [ "parse_journald" ];
            endpoint = "http://loki.service.consul:19832";
            auth = {
              strategy = "basic";
              user = "SECRET[basic_auth.username]";
              password = "SECRET[basic_auth.password]";
            };

            encoding = {
              codec = "json";
            };

            labels = {
              source = "journald";
              host = "{{ host }}";
              unit = "{{ unit }}";
              priority = "{{ priority }}";
            };
          };
        };
      };
    };

    users.users.vector = {
      group = "vector";
      extraGroups = [ "systemd-journal" ];
      isSystemUser = true;
    };
    users.groups.vector = { };
    systemd.services.vector.serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "vector";
      Group = "vector";
    };
  };
}
