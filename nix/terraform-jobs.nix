{ inputs, ... }:
{
  imports = [ inputs.terranix.flakeModule ];

  perSystem =
    {
      pkgs,
      system,
      ...
    }:
    let
      lib = pkgs.lib;

      # Get all .hcl job files from nomad/jobs
      hclJobFiles = builtins.filter (name: lib.hasSuffix ".nomad.hcl" name) (
        builtins.attrNames (builtins.readDir ../nomad/jobs)
      );

      # Build nomad jobs JSON output
      nomadJobsOutput = inputs.self.packages.${system}.nomad-jobs;

      readClean = file: builtins.replaceStrings [ "\${" ] [ "$\${" ] (lib.readFile file);

      terraformJobs = {
        modules = [
          {
            # Terraform backend - using Consul KV for state
            terraform.backend.consul = {
              address = "consul.local.salamon.xyz";
              scheme = "https";
              path = "terraform/jobs";
            };

            # Nomad provider configuration
            provider.nomad = {
              address = "https://nomad.local.salamon.xyz";
              region = "global";
            };

            # Resources for both nix-nomad generated JSON jobs and legacy HCL jobs
            resource.nomad_job =
              let
                # Nix-nomad generated JSON jobs
                nixJobResources = lib.mapAttrs' (
                  name: _:
                  let
                    jobName = lib.removeSuffix ".json" name;
                  in
                  lib.nameValuePair "nix_${jobName}" {
                    jobspec = readClean "${nomadJobsOutput}/${name}";
                    json = true;
                  }
                ) (builtins.readDir nomadJobsOutput);

                # Legacy HCL jobs
                hclJobResources = lib.listToAttrs (
                  map (hclFile: {
                    name = "hcl_${lib.removeSuffix ".nomad.hcl" hclFile}";
                    value = {
                      jobspec = readClean "${../nomad/jobs}/${hclFile}";
                      json = false;
                    };
                  }) hclJobFiles
                );
              in
              nixJobResources // hclJobResources;
          }
        ];
        terraformWrapper.package = pkgs.opentofu;
      };
    in
    {
      terranix.terranixConfigurations.terraform-jobs = terraformJobs;
    };
}
