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
      };
    };
in
{
  options.age.secrets = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule nomadModule);
  };
}
