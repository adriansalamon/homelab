{
  inputs,
  config,
  pkgs,
  lib,
  globals,
  nodes,
  ...
}:
let
  inherit (lib)
    filterAttrs
    mapAttrsToList
    mapAttrs'
    nameValuePair
    ;

  host = config.node.name;
  nomadSecretDir = inputs.self.outPath + "/secrets/nomad/";
in
{
  imports = [ ./common.nix ];

  age.secrets."nomad-client-key.pem" = {
    rekeyFile = "${nomadSecretDir}/global-client-nomad-key.pem.age";
  };

  # { "consul": { "token": "xxxxx" } }
  age.secrets."nomad-secrets.json" = {
    rekeyFile = "${nomadSecretDir}/client.json.age";
  };

  age.secrets = {
    "nebula-ca.key" = {
      rekeyFile = inputs.self.outPath + "/secrets/nebula/mesh/ca.key.age";
    };

    # CONSUL_HTTP_TOKEN=xxxxxxx
    # NOMAD_TOKEN=xxxxxx
    "nebula-nomad-agent.env" = {
      rekeyFile = inputs.self.outPath + "/secrets/consul/nebula-nomad-cni.env.age";
    };
  };

  # Since we use docker, keep docker state please
  environment.persistence."/state".directories = [
    {
      directory = "/var/lib/docker";
      mode = "0700";
      user = "root";
    }
  ];

  virtualisation.docker = {
    daemon.settings = {
      # overlay2 does not work with virtiofs
      storage-driver = "fuse-overlayfs";
    };
    extraPackages = [ pkgs.fuse-overlayfs ];
  };

  boot.initrd.kernelModules = [
    "bridge"
    "br_netfilter"
  ];

  systemd.tmpfiles.rules = [
    "d /var/run/seaweedfs-csi/socket 0700 root root"
    "d /var/run/seaweedfs-csi/staging 0700 root root"
  ];

  services.nomad = {
    enableDocker = true;

    settings = {
      client = {
        enabled = true;
        network_interface = "nebula.mesh";
        cni_path = "${pkgs.cni-plugins}/bin:${pkgs.nebula-nomad-cni}/bin";
        cni_config_dir = "/etc/cni/net.d";

        host_volume."docker-socket" = {
          path = "/var/run/docker.sock";
          read_only = true;
        };

        host_volume."seaweedfs-socket" = {
          path = "/var/run/seaweedfs-csi/socket";
          read_only = false;
        };

        host_volume."csi-data" = {
          path = "/var/lib/nomad/client/csi";
          read_only = false;
        };

        host_volume."nix-store" = {
          path = "/nix/store";
          read_only = true;
        };

        host_volume."nix-daemon-socket" = {
          path = "/nix/var/nix/daemon-socket";
          read_only = false;
        };

        host_volume."nix-bin" = {
          path = "${pkgs.nix}/bin";
          read_only = true;
        };
      };

      tls = {
        cert_file = "${nomadSecretDir}/global-client-nomad.pem";
        key_file = config.age.secrets."nomad-client-key.pem".path;
      };

      telemetry = {
        publish_allocation_metrics = true;
        publish_node_metrics = true;
        prometheus_metrics = true;
      };

      plugin.docker.config = {
        allow_privileged = true; # needed for CSI

        extra_labels = [
          "job_name"
          "task_group_name"
          "task_name"
          "namespace"
          "node_name"
        ];
      };
    };

    credentials.secrets = config.age.secrets."nomad-secrets.json".path;

    extraPackages = with pkgs; [
      cni-plugins
      consul
    ];
  };

  consul.services.nomad-client = {
    port = 4646;
    tags = [
      "prometheus.scrape=true"
      "prometheus.path=/v1/metrics"
      "prometheus.scheme=https"
      "prometheus.query.format=prometheus"
    ];
  };

  services.nebula-nomad-agent =
    let
      externalAddrs = name: [ "${nodes.${name}.config.node.publicIp}:4242" ];

      lighthouses = filterAttrs (_: v: v.lighthouse) globals.nebula.mesh.hosts;
      lightHouseIps = mapAttrsToList (_: lightHouseCfg: lightHouseCfg.ipv4) lighthouses;
      staticHostMap = mapAttrs' (
        name: lighthouseCfg: nameValuePair (lighthouseCfg.ipv4) (externalAddrs name)
      ) lighthouses;
    in
    {
      enable = true;
      defaultNebulaConfig = {
        pki = {
          # Use both old v1 and v2 CA for compatibility
          ca = inputs.self.outPath + "/secrets/nebula/mesh/ca_combined.crt";
        };

        # Default firewall rules
        firewall = {
          outbound = [
            {
              cidr = "0.0.0.0/0";
              host = "any";
              port = "any";
              proto = "any";
            }
          ];
          inbound = [
            {
              cidr = "0.0.0.0/0";
              host = "any";
              port = "any";
              proto = "icmp";
            }
          ];
        };

        static_host_map = staticHostMap;
        lighthouse = {
          am_lighthouse = false;
          hosts = lightHouseIps;
        };

        listen = {
          host = "0.0.0.0";
          port = 0;
        };

        punchy = {
          punch = true;
        };

        tun = {
          disabled = false;
          dev = "nebula1";
          drop_local_broadcast = false;
          drop_multicast = false;
          tx_queue = 500;
          mtu = 1300;
        };
      };

      caKeyPath = config.age.secrets."nebula-ca.key".path;
      caCertPath = inputs.self.outPath + "/secrets/nebula/mesh/ca.crt";

      environmentFile = config.age.secrets."nebula-nomad-agent.env".path;
      nomadAddr = "https://nomad.local.${globals.domains.main}";

      # TODO: use something more sane
      ipPool = {
        networkCIDR = globals.nebula.mesh.cidrv4;
        rangeStart = lib.net.cidr.host 2000 globals.nebula.mesh.cidrv4;
        rangeEnd = lib.net.cidr.host 3000 globals.nebula.mesh.cidrv4;
      };
    };

  systemd = {
    services.cni-dhcp = {
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "cni-dhcp.socket"
      ];
      requires = [ "cni-dhcp.socket" ];
      description = "CNI DHCP service ";
      serviceConfig = {
        ExecStart = "${pkgs.cni-plugins}/bin/dhcp daemon";
        Restart = "always";
        RestartSec = "10s";
      };
    };

    sockets.cni-dhcp = {
      wantedBy = [ "sockets.target" ];
      description = "CNI DHCP service socket";
      partOf = [ "cni-dhcp.service" ];
      socketConfig = {
        ListenStream = "/run/cni/dhcp.sock";
        SocketMode = "0660";
        # TODO: is this safe?
        SocketUser = "root";
        SocketGroup = "root";
        RemoveOnStop = true;
      };
    };
  };

  environment.etc."cni/net.d/10-nebula.conflist".text = builtins.toJSON {
    cniVersion = "1.0.0";
    name = "nebula";
    plugins = [
      { type = "loopback"; }
      {
        type = "bridge";
        name = "brNomad";
        bridge = "nomad";
        isGateway = true;
        ipMasq = true;
        ipam = {
          type = "host-local";
          ranges = [ [ { subnet = "172.26.64.0/20"; } ] ];
          routes = [ ];
        };
      }
      {
        type = "firewall";
        backend = "iptables";
      }
      {
        type = "nebula-nomad-cni";
        socket_path = "/var/run/nebula-cni.sock";
        roles_meta_key = "nebula_roles";
        macvlan = {
          enable = true;
          name = "macv0";
          master = "eth0"; # TODO: make this configurable per host
          ipam = {
            type = "dhcp";
          };
        };
      }
    ];
  };

  globals.nebula.mesh.hosts.${host} = {
    groups = [ "nomad-client" ];

    firewall.inbound = [
      # vxvlan
      {
        port = 8472;
        proto = "udp";
        group = "nomad-client";
      }
      {
        port = 4646;
        proto = "tcp";
        group = "any";
      }
      {
        port = "20000-32000";
        proto = "tcp";
        group = "any";
      }
      {
        port = "20000-32000";
        proto = "udp";
        group = "any";
      }
    ];
  };
}
