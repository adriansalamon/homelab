{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem =
    { pkgs, ... }:
    {
      treefmt = {
        projectRootFile = "flake.nix";
        programs = {
          deadnix.enable = true;
          statix.enable = true;
          nixfmt.enable = true;
        };
      };

      apps.setupHetznerStorageBoxes = import ../apps/setup-hetzner-storage-boxes.nix {
        inherit pkgs;
        inherit (inputs.self) globals nixosConfigurations nomadConfigurations;
        decryptIdentity = (builtins.head inputs.self.secretsConfig.masterIdentities).identity;
      };

      apps.provision-postgres = import ../apps/provision-postgres.nix {
        inherit pkgs;
        inherit (inputs.self) globals;
        inherit (inputs.self.nodes.demeter.config.age) secrets;
        decryptIdentity = (builtins.head inputs.self.secretsConfig.masterIdentities).identity;
      };

      apps.unlock-initrd = import ../apps/unlock-initrd.nix {
        inherit pkgs;
        inherit (inputs.self) globals nixosConfigurations;
        decryptIdentity = (builtins.head inputs.self.secretsConfig.masterIdentities).identity;
      };
    };
}
