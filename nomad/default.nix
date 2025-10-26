{ inputs, ... }:
{
  imports = [
    inputs.home-manager.flakeModules.home-manager
  ];

  flake = {

    # we define a "home" nomad configuration. This enables us to treat nomad like a
    # host with regards to agenix and agenix-rekey. Essentially, we can generate keep
    # secrets in this repo source, and then use a script to upload them to the nomad
    # cluster.
    homeConfigurations."nomad" = inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = inputs.self.pkgs.x86_64-linux;

      modules = [
        inputs.agenix.homeManagerModules.default
        inputs.agenix-rekey.homeManagerModules.default
        ../modules/nomad/secrets.nix
        {
          age.rekey = {
            inherit (inputs.self.secretsConfig) masterIdentities;

            storageMode = "local";
            hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINSwciatdbU2a7lKgjBc2uGze71PVdNCm10hS44kQATm"; # this is a dummy key
            generatedSecretsDir = inputs.self.outPath + "/secrets/generated/nomad";
            localStorageDir = inputs.self.outPath + "/secrets/rekeyed/nomad";
          };

          home = {
            username = "nomad";
            homeDirectory = "/home/nomad";
            stateVersion = "25.05";
          };
        }
      ];
    };
  };
}
