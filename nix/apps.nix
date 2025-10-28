{ inputs, ... }:
{
  perSystem =
    {
      pkgs,
      ...
    }:
    {
      apps.setupHetznerStorageBoxes = import ../apps/setup-hetzner-storage-boxes.nix {
        inherit pkgs;
        nixosConfigurations = inputs.self.nodes;
        decryptIdentity = (builtins.head inputs.self.secretsConfig.masterIdentities).identity;
      };

      apps.tofu = import ../apps/tofu.nix {
        inherit pkgs;
        inherit (inputs.self) globals;
      };

      apps.provision-postgres = import ../apps/provision-postgres.nix {
        inherit pkgs;
        inherit (inputs.self) globals;
        inherit (inputs.self.nodes.demeter.config.age) secrets;
        decryptIdentity = (builtins.head inputs.self.secretsConfig.masterIdentities).identity;
      };

      apps.provision-nomad-secrets = import ../apps/provision-nomad-secrets.nix {
        inherit pkgs inputs;
        decryptIdentity = (builtins.head inputs.self.secretsConfig.masterIdentities).identity;
      };
    };
}
