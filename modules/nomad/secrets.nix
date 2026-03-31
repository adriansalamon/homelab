{ config, lib, ... }:
let
  inherit (lib)
    types
    mkOption
    nameValuePair
    ;

  nomadModule = submod: {
    options = {
      name = mkOption {
        type = lib.types.str;
        description = "Name of the job.";
        default = submod.config._module.args.name;
      };

      secrets = mkOption {
        type = types.attrsOf (
          types.submodule (secretSubmod: {
            freeformType = types.anything;
            options = {

              nomadName = lib.mkOption {
                type = lib.types.str;
                description = "Name of the secret in Nomad.";
                # nomad variables like snake_case
                default = "${lib.replaceStrings [ "-" ] [ "_" ] secretSubmod.config._module.args.name}";
              };

              nomadPath = lib.mkOption {
                type = lib.types.str;
                description = "Nomad path for the variable for this secret.";
                default = "nomad/jobs/${submod.config.name}";
              };

              hashFile = lib.mkOption {
                type = lib.types.nullOr lib.types.path;
                description = "Path to a file containing the hash of the secret. If this exists, the plaintext hash will be uploaded to Nomad instead of the secret itself.";
                default = null;
              };

              sopsFormat = lib.mkOption {
                type = lib.types.str;
                description = "Format of the secret";
                default = "str";
              };

              sopsOutput = lib.mkOption {
                type = types.attrs;
                default = {
                  file = "${submod.config.name}";
                  key = "${secretSubmod.config._module.args.name}";
                  format = "${secretSubmod.config.sopsFormat}";
                };
              };
            };
          })
        );
        description = "Secrets for this job.";
        default = { };
      };
    };
  };
in
{
  options = {
    nomadJobs = mkOption {
      type = types.attrsOf (types.submodule nomadModule);
      default = { };
    };

    age.secrets = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            nomadName = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Nomad name for the variable for this secret.";
            };

            nomadPath = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Nomad path for the variable for this secret.";
            };
            hashFile = mkOption {
              type = types.nullOr types.path;
              default = null;
              description = "Path to a file containing the hash of the secret.";
            };
          };
        }
      );
    };
  };

  config = {
    age.secrets = lib.mkMerge (
      lib.mapAttrsToList (
        jobName: jobConfig:
        lib.mapAttrs' (
          secretName: secretConfig:
          nameValuePair "${jobName}-${secretName}" (removeAttrs secretConfig [ "sopsFormat" ])
        ) jobConfig.secrets
      ) config.nomadJobs
    );
  };
}
