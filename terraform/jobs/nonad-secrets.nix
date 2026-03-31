{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) foldlAttrs;

  secrets = inputs.self.nomadConfigurations."homelab".config.age.secrets;

  grouped = foldlAttrs (
    acc: name: secret:
    let
      path = secret.nomadPath;
      existing = acc.${path} or [ ];
    in
    acc // { ${path} = existing ++ [ { inherit name secret; } ]; }
  ) { } secrets;

  pathToName = path: lib.replaceStrings [ "/" ] [ "_" ] path;
  sopsFile = ref: lib.head (lib.splitString "#" (lib.removePrefix "ref+sops://" ref));
in
{

  terraform.required_providers.sops = {
    source = "carlpett/sops";
    version = "1.4.1";
  };

  provider.sops = { };

  data.sops_file = lib.mapAttrs' (
    path: entries:
    let
      # All entries in a group share the same sops file, so grab from the first
      source_file = sopsFile (lib.head entries).secret.sopsRef;
    in
    lib.nameValuePair (pathToName path) {
      inherit source_file;
    }
  ) grouped;

  # One nomad_variable per group, with all secrets as items
  resource.nomad_variable = lib.mapAttrs' (
    path: entries:
    let
      resName = pathToName path;

      secretRef =
        entry:
        # If we have hashfile - just upload it directly, otherwise use decrypted value
        if entry.secret.hashFile != null then
          builtins.readFile entry.secret.hashFile
        else
          ''''\${data.sops_file.${resName}.data["${entry.secret.nomadName}"]}'';

      items = lib.foldl' (
        acc: entry:
        acc
        // {
          "${entry.secret.nomadName}" = secretRef entry;
        }
      ) { } entries;
    in
    lib.nameValuePair resName {
      inherit path items;
      namespace = "default";
    }
  ) grouped;
}
