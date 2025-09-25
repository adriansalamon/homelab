{ inputs, ... }:
{
  imports = [
    (
      { lib, flake-parts-lib, ... }:
      flake-parts-lib.mkTransposedPerSystemModule {
        name = "pkgs";
        file = ./pkgs.nix;
        option = lib.mkOption { type = lib.types.unspecified; };
      }
    )
  ];

  perSystem =
    { pkgs, system, ... }:
    {
      # Apply overlay to perSystem pkgs
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = (import ../pkgs/default.nix inputs) ++ [
          (import ../lib inputs)
        ];
        config.allowUnfree = true;
      };

      formatter = pkgs.nixfmt-rfc-style;

      inherit pkgs;
    };
}
