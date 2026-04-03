{
  lib,
  inputs,
  system,
  ...
}:
let

  jobsFolderPath = "${inputs.self.outPath}/nomad/jobs/";

  # Get all .hcl job files from nomad/jobs
  hclJobFiles = builtins.filter (name: lib.hasSuffix ".nomad.hcl" name) (
    builtins.attrNames (builtins.readDir jobsFolderPath)
  );

  # Build nomad jobs JSON output
  nomadJobsOutput = inputs.self.packages.${system}.nomad-jobs;

  readClean = file: builtins.replaceStrings [ "\${" ] [ "$\${" ] (lib.readFile file);
in
{
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
            jobspec = readClean "${jobsFolderPath}/${hclFile}";
            json = false;
          };
        }) hclJobFiles
      );
    in
    nixJobResources // hclJobResources;
}
