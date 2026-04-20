{ globals, lib, ... }:
{
  job.renovate = {
    type = "batch";

    periodic = {
      cron = "0 */8 * * *"; # thrice a day
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

        env = {
          RENOVATE_PLATFORM = "forgejo";
          RENOVATE_ENDPOINT = "https://forgejo.${globals.domains.main}";
          RENOVATE_GIT_AUTHOR = "Renovate Bot <renovate@${globals.domains.main}>";
          RENOVATE_REPOSITORIES = "adrian/homelab";
          LOG_LEVEL = "info";
        };

        templates = lib.singleton {
          data = ''
            {{ with secret "secret/data/default/renovate" }}
            RENOVATE_TOKEN={{ .Data.data.forgejo_token }}
            RENOVATE_GITHUB_COM_TOKEN={{ .Data.data.github_token }}
            {{ end }}
          '';
          destination = "\${NOMAD_SECRETS_DIR}/renovate.env";
          env = true;
        };

        resources = {
          cpu = 500;
          memory = 3072;
        };

        restart = {
          attempts = 1;
          mode = "fail";
        };
      };
    };
  };
}
