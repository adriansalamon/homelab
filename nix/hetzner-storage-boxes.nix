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
    };
}
