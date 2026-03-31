{ inputs, ... }:
{
  imports = [ inputs.terranix.flakeModule ];

  perSystem =
    { pkgs, system, ... }:
    let
      lib = pkgs.lib;

      terraformJobs = {
        terraformWrapper.package = pkgs.opentofu;

        extraArgs = {
          inherit inputs system;
        };

        modules = [ ] ++ lib.collect builtins.isPath (lib.rakeLeaves ../terraform/jobs);
      };
    in
    {
      terranix.terranixConfigurations.terraform-jobs = terraformJobs;
    };
}
