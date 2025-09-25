{
  config,
  lib,
  pkgs,
  utils,
  ...
}@inputs:
let
  inherit (lib)
    attrValues
    escapeShellArg
    flatten
    flip
    foldl'
    groupBy
    hasInfix
    hasPrefix
    literalExpression
    makeBinPath
    mapAttrsToList
    genAttrs
    mkIf
    mkMerge
    mkOption
    optional
    types
    warnIf
    disk
    replaceStrings
    ;

  mergeToplevelConfigs = keys: attrs: genAttrs keys (attr: mkMerge (map (x: x.${attr} or { }) attrs));

  # List the necessary mount units for the given guest
  fsMountUnitsFor =
    guestCfg: map (x: "${utils.escapeSystemdPath x.hostMountpoint}.mount") (attrValues guestCfg.zfs);

  genMac =
    string:
    let
      hash = builtins.hashString "sha256" string;
      # Ensure locally administered MAC by forcing first byte to 02
      mac =
        "02:"
        + lib.substring 2 2 hash
        + ":"
        + lib.substring 4 2 hash
        + ":"
        + lib.substring 6 2 hash
        + ":"
        + lib.substring 8 2 hash
        + ":"
        + lib.substring 10 2 hash;
    in
    mac;

  defineGuest = guestName: guestCfg: {
    # Add the required datasets to the disko configuration of the machine
    disko.devices.zpool = mkMerge (
      flip map (attrValues guestCfg.zfs) (zfsCfg: {
        ${zfsCfg.pool}.datasets.${zfsCfg.dataset} =
          # We generate the mountpoint fileSystems entries ourselfs to enable shared folders between guests
          disk.zfs.unmountable;
      })
    );

    systemd.network = mkMerge (
      flip mapAttrsToList guestCfg.microvm.interfaces (
        ifaceName: ifaceCfg: {
          networks."50-microvm-${guestName}-${ifaceName}" = {
            matchConfig.Name = "vm-${replaceStrings [ ":" ] [ "" ] ifaceCfg.mac}";
            networkConfig.Bridge = ifaceCfg.bridge;
          };
        }
      )
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

          "microvm@${guestName}" = {
            requires = fsMountUnitsFor guestCfg;
            after = fsMountUnitsFor guestCfg;
          };
        }
      )
    );

    microvm.vms.${guestName} = import ./microvm.nix guestName guestCfg inputs;
  };

in
{

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
                    bridge = mkOption {
                      type = types.str;
                      description = "The bridge to attach the interface to";
                    };
                    mac = mkOption {
                      type = types.str;
                      description = "The local MAC address of the interface";
                      default = genMac "${config.node.name}-${submod.config._module.args.name}-${submod-iface.config._module.args.name}";
                    };
                  };
                })
              );
              default = { };
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
                      options =
                        [ "zfsutil" ]
                        ++ optional (prev != null)
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
    (mergeToplevelConfigs [ "disko" "systemd" "microvm" "fileSystems" ] (
      mapAttrsToList defineGuest config.guests
    ))
  ]);
}
