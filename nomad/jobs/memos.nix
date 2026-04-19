{ globals, helpers, ... }:
let
  port = "8081";
in
{
  job.memos = {
    type = "service";

    group.memos = {
      count = 1;

      networks = [
        {
          mode = "cni/nebula";
          port.dummy = { };
        }
      ];

      task.memos = {
        driver = "docker";

        vault = { };

        config = {
          image = "neosmemo/memos:0.27.1";
        };

        meta = helpers.mkNebula {
          groups = [ "postgres-client" ];
          firewall.inbound = helpers.nebula.acceptGroups {
            inherit port;
            groups = [
              "reverse-proxy"
              "nomad-client"
            ];
          };
        };

        templates = [
          {
            data = ''
              MEMOS_MODE=prod
              MEMOS_ADDR={{ env "NOMAD_ALLOC_IP_dummy" }}
              MEMOS_PORT=${port}
              MEMOS_DRIVER=postgres
              MEMOS_INSTANCE_URL=https://memos.${globals.domains.main}
            '';
            destination = "local/config.env";
            env = true;
          }
          (helpers.postgresEnv {
            dbName = "memos";
            dbUser = "memos";
            envVar = "MEMOS_DSN";
          })
        ];

        resources = {
          cpu = 250;
          memory = 512;
        };
      };

      services = [
        (helpers.mkService {
          name = "memos";
          inherit port;
          tags = helpers.mkTraefikTags {
            name = "memos";
            external = true;
          };
          checks = [
            (helpers.mkHttpCheck {
              inherit port;
              path = "/healthz";
            })
          ];
        })
      ];
    };
  };
}
