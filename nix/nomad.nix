{ inputs, ... }:
{
  # Nomad jobs derivation
  perSystem =
    {
      pkgs,
      ...
    }:
    let
      lib = pkgs.lib;
      jobsConfig = inputs.nix-nomad.lib.mkNomadJobs {
        inherit pkgs;

        config = lib.collect builtins.isPath (lib.rakeLeaves ../nomad/jobs);

        extraArgs = {
          # helper functions for job files
          helpers = import ../nomad/lib/helpers.nix {
            inherit lib;
            inherit (inputs.self) globals;
            secretsConfig = inputs.self.nomadConfigurations."homelab";
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
                creation_rules = [
                  {
                    # Encrypt everything with age + vault
                    path_regex = ".*";
                    age = (map (cfg: cfg.pubkey) inputs.self.secretsConfig.masterIdentities);
                    hc_vault_transit_uri = "https://vault.local.${config.globals.domains.main}/v1/transit/keys/sops-key";
                  }
                ];
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
