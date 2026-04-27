{
  config,
  lib,
  pkgs,
  utils,
  ...
}@inputs:
let
  inherit (lib)
    attrsToList
    attrValues
    escapeShellArg
    flatten
    flip
    foldl'
    groupBy
    hasInfix
    hasPrefix
    listToAttrs
    literalExpression
    makeBinPath
    mapAttrsToList
    genAttrs
    mapAttrs
    mkIf
    mkMerge
    mkOption
    optional
    types
    warnIf
    disk
    ;

  mergeToplevelConfigs = keys: attrs: genAttrs keys (attr: mkMerge (map (x: x.${attr} or { }) attrs));

  backends = [
    "microvm"
    "container"
  ];

  guestsByBackend =
    genAttrs backends (_: { })
    // mapAttrs (_: listToAttrs) (groupBy (x: x.value.backend) (attrsToList config.guests));

  # List the necessary mount units for the given guest
  fsMountUnitsFor =
    guestCfg: map (x: "${utils.escapeSystemdPath x.hostMountpoint}.mount") (attrValues guestCfg.zfs);

  defineGuest = _guestName: guestCfg: {
    # Add the required datasets to the disko configuration of the machine
    disko.devices.zpool = mkMerge (
      flip map (attrValues guestCfg.zfs) (zfsCfg: {
        ${zfsCfg.pool}.datasets.${zfsCfg.dataset} =
          # We generate the mountpoint fileSystems entries ourselfs to enable shared folders between guests
          disk.zfs.unmountable;
      })
    );

    # Ensure that the zfs dataset exists before it is mounted.
    systemd.services = mkMerge (
      flip map (attrValues guestCfg.zfs) (
        zfsCfg:
        let
          fsMountUnit = "${utils.escapeSystemdPath zfsCfg.hostMountpoint}.mount";
        in
        {
          "zfs-ensure-${utils.escapeSystemdPath "${zfsCfg.pool}/${zfsCfg.dataset}"}" = {
            wantedBy = [ fsMountUnit ];
            before = [ fsMountUnit ];
            after = [
              "zfs-import-${utils.escapeSystemdPath zfsCfg.pool}.service"
              "zfs-mount.target"
            ];
            unitConfig.DefaultDependencies = "no";
            serviceConfig.Type = "oneshot";
            script =
              let
                poolDataset = "${zfsCfg.pool}/${zfsCfg.dataset}";
                diskoDataset = config.disko.devices.zpool.${zfsCfg.pool}.datasets.${zfsCfg.dataset};
              in
              ''
                export PATH=${makeBinPath [ pkgs.zfs ]}":$PATH"
                if ! zfs list -H -o type ${escapeShellArg poolDataset} &>/dev/null ; then
                  ${diskoDataset._create}
                fi
              '';
          };

        }
      )
    );

  };

  defineMicrovm = guestName: guestCfg: {
    systemd.services."microvm@${guestName}" = {
      requires = fsMountUnitsFor guestCfg;
      after = fsMountUnitsFor guestCfg;
    };

    microvm.vms.${guestName} = import ./microvm.nix guestName guestCfg inputs;
  };

  defineContainer = guestName: guestCfg: {
    systemd.services."container@${guestName}" = {
      requires = fsMountUnitsFor guestCfg;
      after = fsMountUnitsFor guestCfg;
      # Don't use the notify service type. Using exec will always consider containers
      # started immediately and donesn't wait until the container is fully booted.
      # Containers should behave like independent machines, and issues inside the container
      # will unnecessarily lock up the service on the host otherwise.
      # This causes issues on system activation or when containers take longer to start
      # than TimeoutStartSec.
      serviceConfig.Type = lib.mkForce "exec";
    };

    containers.${guestName} = import ./container.nix guestName guestCfg inputs;
  };
in
{

  options.containers = mkOption {
    type = types.attrsOf (
      types.submodule (submod: {
        options.nixosConfiguration = mkOption {
          type = types.unspecified;
          default = null;
        };

        config = mkIf (submod.config.nixosConfiguration != null) {
          path = submod.config.nixosConfiguration.config.system.build.toplevel;
        };
      })
    );
  };

  options.guests = mkOption {
    default = { };
    type = types.attrsOf (
      types.submodule (submod: {
        options = {
          name = mkOption {
            type = types.str;
            default = "${config.node.name}-${submod.config._module.args.name}";
            description = "Name of the guest";
          };

          backend = mkOption {
            type = types.enum backends;
            default = "microvm";
          };

          extraSpecialArgs = mkOption {
            type = types.attrs;
            default = { };
            example = literalExpression "{ inherit inputs; }";
            description = ''
              Extra `specialArgs` passed to each guest system definition.
            '';
          };

          microvm = {
            system = mkOption {
              type = types.str;
              description = "The system that the microvm should use";
            };

            interfaces = mkOption {
              description = "An attrset of the interfaces to bind to this microvm";
              type = types.attrsOf (
                types.submodule (submod-iface: {
                  options = {
                    type = mkOption {
                      type = types.str;
                      description = "Type of interface, can be bridge or macvtap.";
                      default = "macvtap";
                    };
                    bridge = mkOption {
                      type = types.str;
                      description = "The bridge to attach the interface to";
                    };
                    mac = mkOption {
                      type = types.str;
                      description = "The local MAC address of the interface";
                      default = lib.net.mac.genLocalMac "${config.node.name}-${submod.config._module.args.name}-${submod-iface.config._module.args.name}";
                    };
                  };
                })
              );
              default = { };
            };
          };

          container = {
            bridge = mkOption {
              type = types.str;
              default = "serverBr";
              description = "Host bridge to attach the container to via a veth pair";
            };

            address = mkOption {
              type = types.str;
              description = "Static IP/prefix for the container's internal interface (e.g. 172.16.0.2/24)";
            };
          };

          zfs = mkOption {
            description = "ZFS datasets to mount to this guest";
            default = { };
            type = types.attrsOf (
              types.submodule (zfsSubmod: {
                options = {
                  pool = mkOption {
                    type = types.str;
                    description = "The host ZFS pool where the dataset exists";
                  };

                  dataset = mkOption {
                    type = types.str;
                    description = "The hosts ZFS dataset to mount (will be auto-created)";
                    example = "safe/guests/guest-name";
                  };

                  hostMountpoint = mkOption {
                    type = types.str;
                    default = "/guests/${submod.config._module.args.name}${zfsSubmod.config.guestMountpoint}";
                    example = "/guests/guest-name/persist";
                    description = "The host's mountpoint for the guest's dataset";
                  };

                  guestMountpoint = mkOption {
                    type = types.path;
                    default = zfsSubmod.config._module.args.name;
                    example = "/persist";
                    description = "The mountpoint inside the guest.";
                  };
                };
              })
            );
          };

          autostart = mkOption {
            type = types.bool;
            default = false;
            description = "Guest should be started automatically with the host";
          };

          modules = mkOption {
            type = types.listOf types.unspecified;
            default = [ ];
            description = "Additional modules to load";
          };
        };

      })
    );
  };

  config = mkIf (config.guests != { }) (mkMerge [
    {
      systemd.tmpfiles.rules = [ "d /guests 0700 root root -" ];

      # To enable shared folders we need to do all fileSystems entries ourselfs
      fileSystems =
        let
          zfsDefs = flatten (
            flip mapAttrsToList config.guests (
              _: guestCfg:
              flip mapAttrsToList guestCfg.zfs (
                _: zfsCfg: {
                  path = "${zfsCfg.pool}/${zfsCfg.dataset}";
                  inherit (zfsCfg) hostMountpoint;
                }
              )
            )
          );
          # Due to limitations in zfs mounting we need to explicitly set an order in which
          # any dataset gets mounted
          zfsDefsByPath = flip groupBy zfsDefs (x: x.path);
        in
        mkMerge (
          flip mapAttrsToList zfsDefsByPath (
            _: defs:
            (foldl'
              (
                { prev, res }:
                elem: {
                  prev = elem;
                  res = res // {
                    ${elem.hostMountpoint} = {
                      fsType = "zfs";
                      options = [
                        "zfsutil"
                      ]
                      ++
                        optional (prev != null)
                          "x-systemd.requires-mounts-for=${
                            warnIf (hasInfix " " prev.hostMountpoint)
                              "HostMountpoint ${prev.hostMountpoint} cannot contain a space"
                              prev.hostMountpoint
                          }";
                      device = elem.path;
                    };
                  };
                }
              )
              {
                prev = null;
                res = { };
              }
              defs
            ).res
          )
        );

      assertions = flatten (
        flip mapAttrsToList config.guests (
          guestName: guestCfg:
          flip mapAttrsToList guestCfg.zfs (
            zfsName: zfsCfg: {
              assertion = hasPrefix "/" zfsCfg.guestMountpoint;
              message = "guest ${guestName}: zfs ${zfsName}: the guestMountpoint must be an absolute path.";
            }
          )
        )
      );
    }
    (mergeToplevelConfigs [ "disko" "systemd" "fileSystems" ] (
      mapAttrsToList defineGuest config.guests
    ))
    (mergeToplevelConfigs [ "containers" "systemd" ] (
      mapAttrsToList defineContainer guestsByBackend.container
    ))
    (mergeToplevelConfigs [ "microvm" "systemd" ] (
      mapAttrsToList defineMicrovm guestsByBackend.microvm
    ))
  ]);
}
