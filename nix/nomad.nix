{ inputs, ... }:
{
  imports = [
    inputs.home-manager.flakeModules.home-manager
  ];

  flake =
    { config, lib, ... }:
    let
      pkgs = config.pkgs.x86_64-linux;
    in
    {
      # we define a "home" nomad configuration. This enables us to treat nomad like a
      # host with regards to agenix and agenix-rekey. Essentially, we can generate keep
      # secrets in this repo source, and then use a script to upload them to the nomad
      # cluster.
      homeConfigurations."nomad" = inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.self.pkgs.x86_64-linux;
        extraSpecialArgs = {
          inherit (inputs) agenix;
          inherit inputs;
          inherit (config) nodes globals;
        };

        modules = [
          inputs.agenix.homeManagerModules.default
          inputs.agenix-rekey.homeManagerModules.default
          ../modules/nomad/secrets.nix
          {
            age.rekey = {
              inherit (inputs.self.secretsConfig) masterIdentities;

              storageMode = "local";
              hostPubkey = "age1qyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqs3290gq"; # this is a dummy key
              generatedSecretsDir = inputs.self.outPath + "/secrets/generated/nomad";
              localStorageDir = inputs.self.outPath + "/secrets/rekeyed/nomad";
            };

            home = {
              username = "nomad";
              homeDirectory = "/home/nomad";
              stateVersion = "25.05";
            };
          }
        ]
        ++ lib.collect builtins.isPath (pkgs.lib.rakeLeaves ../nomad/secrets);
      };
    };
}
