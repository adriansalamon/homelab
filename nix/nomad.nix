{ inputs, ... }:
{
  # Nomad jobs derivation
  perSystem =
    {
      pkgs,
      ...
    }:
    let
      jobsConfig = inputs.nix-nomad.lib.mkNomadJobs {
        inherit pkgs;

        config = builtins.attrValues (pkgs.lib.rakeLeaves ../nomad/jobs);

        extraArgs = {
          # helper functions for job files
          helpers = import ../nomad/lib/helpers.nix {
            lib = pkgs.lib;
            inherit (inputs.self) globals;
          };

          inherit (inputs.self) globals;
        };
      };
    in
    {
      packages.nomad-jobs =
        pkgs.runCommand "nomad-jobs"
          {
            _ = jobsConfig; # Ensure jobsConfig derivation is built
          }
          ''
            mkdir -p $out
            cp -r ${jobsConfig}/. $out/
            echo $out
          '';
    };

  flake =
    { config, ... }:
    let
      pkgs = config.pkgs.x86_64-linux;
      lib = pkgs.lib;
    in
    {
      nomadConfigurations."homelab" = lib.mkNomadConfiguration {
        inherit pkgs inputs;

        extraSpecialArgs = {
          inherit (inputs) agenix;
          inherit (config) nodes globals;
        };

        modules = [
          {
            age = {
              sops = {
                outputDir = inputs.self.outPath + "/secrets/rekeyed/nomad";
                recipients = [
                  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOg0phKMml4tg+kH2qZOUVi9NT6roXfiDRTLJ4Si3xtP" # CI key
                ]
                ++ (map (cfg: cfg.pubkey) inputs.self.secretsConfig.masterIdentities);
              };

              rekey = {
                inherit (inputs.self.secretsConfig) masterIdentities;

                recipientIdentifier = "nomad";
                storageMode = "local";
                generatedSecretsDir = inputs.self.outPath + "/secrets/generated/nomad";
                localStorageDir = inputs.self.outPath + "/secrets/rekeyed/nomad";
              };
            };
          }
        ]
        ++ lib.collect builtins.isPath (lib.rakeLeaves ../nomad/secrets);
      };
    };
}
