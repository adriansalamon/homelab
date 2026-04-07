{
  lib,
  stdenv,
  plugins,
}:

# Vault can't deal with plugins that are symlinks:
# https://github.com/hashicorp/vault/pull/7584
#
# This derivation copies the Vault plugins into a directory.
let
  installPlugins = builtins.concatStringsSep "\n" (
    map (
      pkg:
      let
        pkgName = lib.getName pkg;
      in
      ''
        install ${pkg}/bin/${pkgName} -m 0555 $out/${pkgName}
      ''
    ) plugins
  );

in
stdenv.mkDerivation {
  pname = "vault-plugins";
  version = "1";

  dontUnpack = true;

  installPhase = ''
    mkdir -p $out
    ${installPlugins}
  '';

  meta = with lib; {
    description = "A collection of Vault plugins";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
