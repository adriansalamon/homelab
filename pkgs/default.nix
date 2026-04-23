inputs: [
  (_final: prev: {
    kea-ddns-consul = prev.callPackage ./kea-ddns-consul { };
    nebula-keygen-age = prev.callPackage ./nebula-keygen-age { };
    rustic-exporter = prev.callPackage ./rustic-exporter { };
    nixos-auto-updater = prev.callPackage ./nixos-auto-updater { };
    vault-plugins = prev.callPackage ./vault-plugins {
      plugins = [ inputs.nebula-vault-plugin.packages.${prev.stdenv.hostPlatform.system}.default ];
    };
  })
]
