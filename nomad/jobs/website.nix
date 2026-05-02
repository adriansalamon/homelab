{ helpers, globals, ... }:
let
  port = "80";
in
{
  job.website = {
    type = "service";

    group.website = {
      count = 2;

      networks = [
        {
          mode = "cni/nebula";
        }
      ];

      task.website = {
        driver = "docker";

        config = {
          image = "forgejo.salamon.xyz/adrian/website:5e3b9aa";
        };

        meta = helpers.mkNebula {
          groups = [ ];
          firewall.inbound = helpers.nebula.acceptGroups {
            inherit port;
            groups = [ "reverse-proxy" ];
          };
        };

        resources = {
          cpu = 100;
          memory = 50;
          disk = 50;
        };
      };

      services = [
        (helpers.mkService {
          name = "website";
          inherit port;
          tags = [
            "traefik.external=true"
            "traefik.enable=true"
            "traefik.http.routers.website.rule=Host(`${globals.domains.me}`)"
            "traefik.http.routers.website.entrypoints=websecure"
          ];
        })
      ];
    };
  };
}
