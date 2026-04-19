{ globals, lib, ... }:
{
  job.renovate = {
    type = "batch";

    periodic = {
      cron = "0 */12 * * *"; # Twice a day
      prohibitOverlap = true;
      timeZone = "Europe/Stockholm";
    };

    group.renovate = {
      networks = lib.singleton { mode = "cni/nebula"; };

      task.renovate = {
        driver = "docker";

        vault = { };

        config = {
          image = "renovate/renovate:43";
        };

        templates = [
          {
            data = ''
              {{ with secret "secret/data/default/renovate" }}
              RENOVATE_TOKEN={{ .Data.data.forgejo_token }}
              RENOVATE_GITHUB_COM_TOKEN={{ .Data.data.github_token }}
              {{ end }}
              RENOVATE_PLATFORM=forgejo
              RENOVATE_ENDPOINT=https://forgejo.${globals.domains.main}
              RENOVATE_GIT_AUTHOR='Renovate Bot <renovate@${globals.domains.main}>'
              RENOVATE_REPOSITORIES=adrian/homelab
              LOG_LEVEL=info
            '';
            destination = "\${NOMAD_SECRETS_DIR}/renovate.env";
            env = true;
          }
        ];

        resources = {
          cpu = 500;
          memory = 512;
          memoryMax = 1024;
        };

        restart = {
          attempts = 1;
          mode = "fail";
        };
      };
    };
  };
}
