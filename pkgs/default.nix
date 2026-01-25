_inputs: [
  (final: prev: {
    kea-ddns-consul = prev.callPackage ./kea-ddns-consul { };
    nebula-keygen-age = prev.callPackage ./nebula-keygen-age { };
    rustic-exporter = prev.callPackage ./rustic-exporter { };
    homepage = prev.callPackage ./homepage { };
    nixos-auto-updater = prev.callPackage ./nixos-auto-updater { };
    coredns-blocker = prev.callPackage ./coredns { };
  })
]
