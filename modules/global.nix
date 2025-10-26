{ lib, options, ... }:
let

  inherit (lib) mkOption types;

  networkOptions = netSubmod: {
    cidrv4 = mkOption {
      type = types.net.cidrv4;
      description = "IPv4 CIDR block for this network";
      example = "10.1.10.0/24";
    };

    hosts = mkOption {
      default = { };
      type = types.attrsOf (
        types.submodule (hostSubmod: {
          options = {
            id = mkOption {
              type = types.ints.between 1 254;
              description = "Host ID within the network (1-254)";
            };

            mac = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "MAC address of the host";
              example = "aa:bb:cc:dd:ee:ff";
            };

            ipv4 = mkOption {
              type = types.nullOr types.str;
              description = "The IPv4 of the host. Generated";
              readOnly = true;
              default =
                if netSubmod.config.cidrv4 == null then
                  null
                else
                  lib.net.cidr.host hostSubmod.config.id netSubmod.config.cidrv4;
            };

            cidrv4 = mkOption {
              type = types.nullOr types.str;
              description = "The IPv4 of this host including CIDR mask";
              readOnly = true;
              default =
                if netSubmod.config.cidrv4 == null then
                  null
                else
                  lib.net.cidr.hostCidr hostSubmod.config.id netSubmod.config.cidrv4;
            };
          };
        })
      );
    };
  };

  defaultMonitorOptions = {
    network = mkOption {
      type = types.str;
      description = "The network which this resource is monitored by.";
    };
  };

  nebula = mkOption {
    default = { };
    type = types.attrsOf (
      types.submodule (
        { config, ... }:
        let
          globalCfg = config;
        in
        {
          options = {
            cidrv4 = mkOption {
              type = types.net.cidrv4;
              description = "IPv4 nebula overlay network";
            };
            hosts = mkOption {
              default = { };
              description = "Attrset of hostname to nebula config";
              type = types.attrsOf (
                types.submodule (
                  { config, ... }:
                  {
                    options = {
                      lighthouse = mkOption {
                        type = types.bool;
                        description = "Set this node as lighthouse node";
                        default = false;
                      };

                      id = mkOption {
                        type = types.int;
                        description = ''
                          ID of the node. Used to derive the Nebula IP address.
                          Has to be smaller than the size of the overlay network.
                        '';
                      };

                      ipv4 = mkOption {
                        type = types.nullOr types.net.ipv4;
                        default = if (globalCfg.cidrv4 == null) then null else lib.net.cidr.host config.id globalCfg.cidrv4;
                        readOnly = true;
                        description = "The IPv4 of this host. Automatically computed from the {option}`id`";
                      };

                      routeSubnets = mkOption {
                        type = types.listOf types.net.cidrv4;
                        default = [ ];
                        description = ''
                          List of unsafe_routes to be added to the nodes certificate.
                          You will need to regenerate the node's keys after adding this.
                        '';
                      };

                      groups = mkOption {
                        type = types.listOf types.str;
                        default = [ ];
                        description = ''
                          List of groups to be added to the nodes certificate.
                          You will need to regenerate the node's keys after adding this.
                        '';
                      };

                      firewall = mkOption {
                        default = { };
                        type = types.submodule {
                          options = {
                            inbound = mkOption {
                              type = types.listOf types.attrs;
                              default = [ ];
                              description = "List of inbound firewall rules";
                            };

                            outbound = mkOption {
                              type = types.listOf types.attrs;
                              default = [ ];
                              description = "List of outbound firewall rules";
                            };
                          };
                        };
                      };

                      # gets passed to services.nebula.<name> options
                      config = mkOption {
                        type = types.attrs;
                        default = { };
                        description = "Extra configuration for the nebula service. See the `services.nebula.networks.<name>` for more information.";
                      };
                    };
                  }
                )
              );
            };
          };
        }
      )
    );
  };

  sites = mkOption {
    default = { };

    type = types.attrsOf (
      types.submodule (siteSubmod: {
        options = networkOptions siteSubmod // {
          airvpn = mkOption {
            type = types.submodule {
              options = {
                port = mkOption {
                  type = types.ints.between 1 65535;
                  description = "Port for the AirVPN tunnel";
                  default = null;
                };

                local-cidrv4 = mkOption {
                  type = types.net.cidrv4;
                  description = "Local IPv4 address for the AirVPN tunnel";
                  default = null;
                };
              };
            };
          };

          default = networkOptions siteSubmod;

          vlans = mkOption {
            type = types.attrsOf (
              types.submodule (vlanSubmod: {
                options = networkOptions vlanSubmod // {
                  id = mkOption {
                    type = types.ints.between 1 4094;
                    description = "VLAN ID (1-4094)";
                  };

                  name = mkOption {
                    description = "The name of this VLAN";
                    default = vlanSubmod.config._module.args.name;
                    type = types.str;
                  };

                  trusted = mkOption {
                    description = "Whether this VLAN is trusted. Untrusted VLANs will not be used for DNS.";
                    type = types.bool;
                    default = true;
                  };
                };
              })
            );
          };
        };
      })
    );
  };

  monitoring = {
    ping = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = defaultMonitorOptions // {
            ipv4addr = mkOption {
              type = types.str;
              description = "The IP/hostname to ping via ipv4.";
            };
          };
        }
      );
    };

    http = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = defaultMonitorOptions // {
            url = mkOption {
              type = types.either (types.listOf types.str) types.str;
              description = "The url to connect to.";
            };

            expectedStatus = mkOption {
              type = types.int;
              default = 200;
              description = "The HTTP status code to expect.";
            };

            expectedBodyRegex = mkOption {
              type = types.nullOr types.str;
              description = "A regex pattern to expect in the body.";
              default = null;
            };
          };
        }
      );
    };

    dns = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = defaultMonitorOptions // {
            server = mkOption {
              type = types.str;
              description = "The DNS server to query.";
            };

            domain = mkOption {
              type = types.str;
              description = "The domain to query.";
            };

            recordType = mkOption {
              type = types.str;
              description = "The record type to query.";
              default = "A";
            };
          };
        }
      );
    };

    tcp = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = defaultMonitorOptions // {
            host = mkOption {
              type = types.str;
              description = "The host to connect to.";
            };

            port = mkOption {
              type = types.port;
              description = "The port to connect to.";
            };
          };
        }
      );
    };
  };

in
{

  options = {
    globals = mkOption {
      default = { };
      type = types.submodule {
        options = {
          inherit sites nebula monitoring;

          loki-secrets = mkOption {
            default = [ ];
            description = "Secrets to be aggregated for loki basic auth";
            type = types.listOf types.attrs;
          };

          domains = mkOption {
            default = { };
            type = types.attrsOf types.str;
          };

          deploy = mkOption {
            type = types.attrsOf (
              types.submodule {
                options = {
                  ip = mkOption {
                    type = types.str;
                    description = "IP address of the node";
                  };
                  sshOpts = mkOption {
                    type = types.listOf types.str;
                    description = "Options to pass to ssh";
                    default = [ ];
                  };
                };
              }
            );
            default = { };
            description = "Nodes to deploy";
          };

          users = mkOption {
            default = [ ];
            type = types.listOf types.str;
            description = "List of users";
          };

          hetzner.storageboxes = mkOption {
            default = { };
            type = types.attrsOf (
              types.submodule {
                options = {
                  mainUser = mkOption {
                    type = types.str;
                    description = "Username of the storage box";
                  };

                  users = mkOption {
                    default = { };
                    description = "Subusers";
                    type = types.attrsOf (
                      types.submodule {
                        options = {
                          subUid = mkOption {
                            type = types.int;
                            description = "The subuser id";
                          };

                          path = mkOption {
                            type = types.str;
                            description = "The home path for this subuser (i.e. backup destination)";
                          };
                        };
                      }
                    );
                  };
                };
              }
            );
          };

          consul-servers = mkOption {
            default = [ ];
            type = types.listOf types.str;
          };

          databases = mkOption {
            default = { };
            type = types.attrsOf (
              types.submodule {
                options = {
                  owner = mkOption {
                    type = types.str;
                    description = "Owner of the database, gets created if it doesn't exist";
                  };
                };
              }
            );
          };
        };
      };
    };

    _globalsDefs = mkOption {
      type = types.unspecified;
      default = options.globals.definitions;
      readOnly = true;
      internal = true;
    };
  };
}
