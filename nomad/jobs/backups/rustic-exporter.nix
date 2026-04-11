{
  pkgs,
  lib,
  globals,
  nodes,
  secretsConfig,
  helpers,
  ...
}:
let
  inherit (lib)
    mapAttrsToList
    attrValues
    filterAttrs
    concatMap
    unique
    attrNames
    ;

  port = 6780;

  escapeSecret = name: builtins.replaceStrings [ "-" ] [ "_" ] name;

  box = globals.hetzner.storageboxes."cloud-backups";

  mkBackup =
    {
      name,
      secretKey,
      subuser,
    }:
    {
      inherit name;
      repository = "opendal:sftp";
      password_file = "/secrets/${secretKey}";
      options = {
        endpoint = "ssh://${box.mainUser}.your-storagebox.de:23";
        user = box.mainUser;
        key = "/secrets/ssh_private_key";
        root = "/home/${box.users.${subuser}.path}/repo/";
        known_hosts_strategy = "Accept";
      };
    };

  backupSources =
    # Manual backups
    mapAttrsToList
      (name: subuser: {
        inherit name subuser;
        secretKey = "${subuser}_hetzner_repo_key";
      })
      {
        "adrian-cloud-backups" = "adrian";
        "christian-cloud-backups" = "christian";
      }
    # NixOS node backups
    ++ concatMap (
      node:
      map (boxCfg: {
        name = "${node}-${boxCfg.name}-${boxCfg.subuser}";
        secretKey = "${node}_repo_key";
        subuser = boxCfg.subuser;
      }) (attrValues nodes.${node}.config.meta.backups.storageboxes)
    ) (attrNames (filterAttrs (_: hostCfg: hostCfg.config.meta.backups.storageboxes != { }) nodes))
    # Nomad backup jobs
    ++ mapAttrsToList (name: cfg: {
      inherit name;
      secretKey = "${name}_repo_key";
      subuser = cfg.subuser;
    }) secretsConfig.config.backups;

  # Generate all backup configs and deduplicate secret keys
  allBackups = map mkBackup backupSources;
  allSecretKeys = unique (map (b: b.secretKey) backupSources);

  # Generate rustic-exporter config file
  rusticConfig = {
    backup = allBackups;
  };

  configFile = (pkgs.formats.toml { }).generate "rustic-exporter-config.toml" rusticConfig;

  # Unified secret template builder
  mkSecretTemplate = secretKey: {
    data = ''
      {{ with secret "secret/data/default/rustic-exporter" }}{{ .Data.data.${escapeSecret secretKey} }}{{ end }}
    '';
    destination = "secrets/${secretKey}";
    perms = "0600";
  };
in
{
  job.rustic-exporter = {
    type = "service";

    group.exporter = {
      count = 1;

      networks = [
        {
          mode = "cni/nebula";
          port.dummy = { };
        }
      ];

      services = [
        (helpers.mkService {
          name = "rustic-exporter";
          inherit port;
          tags = [ "prometheus.scrape=true" ];
        })
      ];

      task.rustic-exporter = {
        driver = "docker";

        vault = { };

        meta = helpers.mkNebula {
          groups = [ "metrics-exporter" ];
          firewall.inbound = [
            {
              inherit port;
              proto = "tcp";
              group = "metrics-collector";
            }
          ];
        };

        env = {
          RUST_LOG = "debug";
        };

        config = {
          image = "ghcr.io/adriansalamon/rustic-exporter:latest-alpine";
          args = [
            "--config"
            "/local/config.toml"
            "--host"
            "\${NOMAD_ALLOC_IP_dummy}"
            "--port"
            port
          ];
        };

        templates = [
          {
            data = builtins.readFile configFile;
            destination = "local/config.toml";
          }
          # SSH private key
          {
            data = ''
              {{ with secret "secret/data/default/rustic-exporter" }}{{ .Data.data.ssh_private_key }}
              {{ end }}
            '';
            destination = "secrets/ssh_private_key";
            perms = "0600";
          }
        ]
        # Generate templates for all secret keys
        ++ map mkSecretTemplate allSecretKeys;

        resources = {
          cpu = 200;
          memory = 512;
        };

        restart = {
          attempts = 3;
          delay = 30 * lib.time.second;
          mode = "fail";
        };
      };
    };
  };
}
