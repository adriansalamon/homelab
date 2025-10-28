{ lib, ... }:
let
  nomadModule =
    { ... }:
    {
      options = {
        nomadPath = lib.mkOption {
          type = lib.types.str;
          description = "Nomad path for the variable for this secret.";
          example = "nomad/jobs/my-job";
        };

        hashFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          description = "Path to a file containing the hash of the secret. If this exists, the plaintext hash will be uploaded to Nomad instead of the secret itself.";
          default = null;
        };
      };
    };
in
{
  options.age.secrets = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule nomadModule);
  };
}
