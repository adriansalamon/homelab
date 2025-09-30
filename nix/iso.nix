{ inputs, ... }:
{
  flake =
    {
      config,
      ...
    }:
    let
      pkgs = config.pkgs.x86_64-linux;
    in
    {
      live-iso = inputs.nixos-generators.nixosGenerate {
        inherit pkgs;
        modules = [
          ./installer-config.nix
        ];
        format = "install-iso";
      };
    };
}
