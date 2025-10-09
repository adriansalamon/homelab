{
  config,
  pkgs,
  lib,
  globals,
  ...
}:
let
  adminConfigPath = "/run/couchdb/admin.ini";
  port = 5984;

  hostname = "127.0.0.1:5984";
  username = "admin";
in
{
  # CouchDB for obisidian-livesync

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/couchdb";
      mode = "0700";
      user = "couchdb";
      group = "couchdb";
    }
  ];

  # TODO: explicit backups

  age.secrets.couchdb-password = {
    generator.script = "alnum";
    owner = "couchdb";
  };

  services.couchdb = {
    enable = true;
    bindAddress = "0.0.0.0";
    inherit port;
    adminUser = "admin";
    extraConfigFiles = [ adminConfigPath ];
  };

  systemd.services.couchdb = {
    preStart = lib.mkBefore ''
      cat > ${adminConfigPath} << EOF
      [admins]
      ${config.services.couchdb.adminUser} = $(cat "${config.age.secrets.couchdb-password.path}")
      EOF
    '';
  };

  environment.systemPackages = [ pkgs.curl ];

  # TODO: Configure using config file, this is cringe

  systemd.services.obisidian-livesync-couchdb-init = {
    description = "Initialize CouchDB database";
    serviceConfig = {
      Type = "oneshot";
      User = "couchdb";
      Group = "couchdb";
      RestartSec = 5;
      StartLimitBurst = 5;
    };
    script =
      let
        curl = "${pkgs.curl}/bin/curl";
      in
      ''
        #!/bin/bash
        export password=$(cat ${config.age.secrets.couchdb-password.path})
        echo "-- Configuring CouchDB by REST APIs... -->"

        until (${curl} -X POST "${hostname}/_cluster_setup" -H "Content-Type: application/json" -d "{\"action\":\"enable_single_node\",\"username\":\"${username}\",\"password\":\"''${password}\",\"bind_address\":\"0.0.0.0\",\"port\":5984,\"singlenode\":true}" --user "${username}:''${password}"); do sleep 5; done
        until (${curl} -X PUT "${hostname}/_node/couchdb@127.0.0.1/_config/chttpd/require_valid_user" -H "Content-Type: application/json" -d '"true"' --user "${username}:''${password}"); do sleep 5; done
        until (${curl} -X PUT "${hostname}/_node/couchdb@127.0.0.1/_config/chttpd_auth/require_valid_user" -H "Content-Type: application/json" -d '"true"' --user "${username}:''${password}"); do sleep 5; done
        until (${curl} -X PUT "${hostname}/_node/couchdb@127.0.0.1/_config/httpd/WWW-Authenticate" -H "Content-Type: application/json" -d '"Basic realm=\"couchdb\""' --user "${username}:''${password}"); do sleep 5; done
        until (${curl} -X PUT "${hostname}/_node/couchdb@127.0.0.1/_config/httpd/enable_cors" -H "Content-Type: application/json" -d '"true"' --user "${username}:''${password}"); do sleep 5; done
        until (${curl} -X PUT "${hostname}/_node/couchdb@127.0.0.1/_config/chttpd/enable_cors" -H "Content-Type: application/json" -d '"true"' --user "${username}:''${password}"); do sleep 5; done
        until (${curl} -X PUT "${hostname}/_node/couchdb@127.0.0.1/_config/chttpd/max_http_request_size" -H "Content-Type: application/json" -d '"4294967296"' --user "${username}:''${password}"); do sleep 5; done
        until (${curl} -X PUT "${hostname}/_node/couchdb@127.0.0.1/_config/couchdb/max_document_size" -H "Content-Type: application/json" -d '"50000000"' --user "${username}:''${password}"); do sleep 5; done
        until (${curl} -X PUT "${hostname}/_node/couchdb@127.0.0.1/_config/cors/credentials" -H "Content-Type: application/json" -d '"true"' --user "${username}:''${password}"); do sleep 5; done
        until (${curl} -X PUT "${hostname}/_node/couchdb@127.0.0.1/_config/cors/origins" -H "Content-Type: application/json" -d '"app://obsidian.md,capacitor://localhost,http://localhost"' --user "${username}:''${password}"); do sleep 5; done

        echo "<-- Configuring CouchDB by REST APIs Done!"
      '';
    after = [ "couchdb.service" ];
    requires = [ "couchdb.service" ];
    partOf = [ "couchdb.service" ];
  };

  consul.services.couchdb = {
    inherit port;
    tags = [
      "traefik.enable=true"
      "traefik.external=true"
      "traefik.http.routers.couchdb.rule=Host(`obsidian.${globals.domains.main}`)"
      "traefik.http.routers.couchdb.entrypoints=websecure"
      "traefik.http.routers.couchdb.middlewares=obsidiancors"
      "traefik.http.middlewares.obsidiancors.headers.accesscontrolallowmethods=GET,PUT,POST,HEAD,DELETE"
      "traefik.http.middlewares.obsidiancors.headers.accesscontrolallowheaders=accept,authorization,content-type,origin,referer"
      "traefik.http.middlewares.obsidiancors.headers.accesscontrolalloworiginlist=app://obsidian.md,capacitor://localhost,http://localhost"
      "traefik.http.middlewares.obsidiancors.headers.accesscontrolmaxage=3600"
      "traefik.http.middlewares.obsidiancors.headers.addvaryheader=true"
      "traefik.http.middlewares.obsidiancors.headers.accessControlAllowCredentials=true"
    ];
  };

  globals.nebula.mesh.hosts.zeus.firewall.inbound = [
    {
      port = builtins.toString port;
      proto = "tcp";
      group = "reverse-proxy";
    }
  ];
}
