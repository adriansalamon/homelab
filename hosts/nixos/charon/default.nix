{
  inputs,
  config,
  globals,
  nodes,
  ...
}:
{
  # Router at Erebus
  imports = [
    ../../../config
    ../../../config/optional/zfs.nix
    ../../../config/optional/impermanence.nix
    ../../../config/optional/hardware.nix

    ./hw.nix
    ./disk-config.nix
    ./net.nix
    ./dns.nix
    ./traefik.nix
    ./firezone.nix
  ];

  age.secrets."consul-acl.json" = {
    rekeyFile = inputs.self.outPath + "/secrets/consul/agent.acl.json.age";
    owner = "consul";
  };

  services.consul = {
    enable = true;
    extraConfig = {
      server = false;
      bind_addr = globals.nebula.mesh.hosts.charon.ipv4;
      retry_join = [
        globals.nebula.mesh.hosts.icarus.ipv4
        globals.nebula.mesh.hosts.athena.ipv4
      ];

      acl = {
        enabled = true;
        default_policy = "deny";
      };
    };

    extraConfigFiles = [
      config.age.secrets."consul-acl.json".path
    ];
  };

  meta.vector.enable = true;
  meta.prometheus.enable = true;

  # Dynamic dns
  age.secrets.cloudflare-dns-api-token = {
    inherit (nodes.athena.config.age.secrets.cloudflare-dns-api-token) rekeyFile;
  };

  services.cloudflare-dyndns = {
    enable = true;
    apiTokenFile = config.age.secrets.cloudflare-dns-api-token.path;
    domains = [ "erebus.site.${globals.domains.main}" ];
  };

  system.stateVersion = "25.05";
}
