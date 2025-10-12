_inputs: [
  (final: prev: {
    kea-ddns-consul = prev.callPackage ./kea-ddns-consul { };
    nebula-keygen-age = prev.callPackage ./nebula-keygen-age { };
    rustic-exporter = prev.callPackage ./rustic-exporter { };
  })
]
