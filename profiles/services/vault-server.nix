{
  inputs,
  globals,
  config,
  pkgs,
  lib,
  ...
}:
let

  host = config.node.name;

  nebulaIp = globals.nebula.mesh.hosts.${host}.ipv4;

  vaultSecretDir = inputs.self.outPath + "/secrets/vault/";

  # Create SANs for the certificate
  dnsNames = [
    "vault.service.consul"
    "active.vault.service.consul"
    "standby.vault.service.consul"
  ];

  ipAddresses = [
    nebulaIp
    "127.0.0.1"
  ];

  sanConfig = ''
    subjectAltName = @alt_names

    [alt_names]
    ${lib.concatImapStringsSep "\n" (i: dns: "DNS.${toString i} = ${dns}") dnsNames}
    ${lib.concatImapStringsSep "\n" (i: ip: "IP.${toString i} = ${ip}") ipAddresses}
  '';
in
{

  # Persist vault data across reboots
  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/vault";
      mode = "0700";
      user = "vault";
      group = "vault";
    }
  ];

  # AWS_ACCESS_KEY_ID=xxx
  # AWS_SECRET_ACCESS_KEY=xxx
  age.secrets."aws-kms.env" = {
    rekeyFile = vaultSecretDir + "aws-kms.env.age";
  };

  # Generate TLS certificate from CA
  age.secrets."vault-server-key.pem" = {
    owner = "vault";
    group = "vault";
    mode = "0600";
    generator = {
      tags = [ "vault-cert" ];
      script =
        {
          pkgs,
          file,
          decrypt,
          ...
        }:
        let
          pubkeyPath = lib.escapeShellArg (lib.removeSuffix "key.pem.age" file + "crt.pem");
          caKeyPath = lib.escapeShellArg (vaultSecretDir + "vault-ca-key.pem.age");
          caCertPath = lib.escapeShellArg (vaultSecretDir + "vault-ca.pem");
        in
        ''
          # Generate server private key
          KEY_FILE=$(mktemp)
          CSR_FILE=$(mktemp)
          EXT_FILE=$(mktemp)

          # Generate private key
          ${pkgs.openssl}/bin/openssl genrsa 4096 > "$KEY_FILE"

          # Create certificate signing request
          ${pkgs.openssl}/bin/openssl req -new -key "$KEY_FILE" \
            -out "$CSR_FILE" \
            -subj "/CN=${host}.vault.service.consul" >&2

          # Create extensions config with SANs
          cat > "$EXT_FILE" <<EOF
          ${sanConfig}
          EOF

          ${decrypt} ${caKeyPath} | ${pkgs.openssl}/bin/openssl x509 -req \
            -in "$CSR_FILE" \
            -CA ${caCertPath} \
            -CAkey /dev/stdin \
            -out ${pubkeyPath} \
            -days 3650 \
            -extfile "$EXT_FILE" >&2

          # Output the private key (will be encrypted by agenix)
          cat "$KEY_FILE"

          # Cleanup
          rm -f "$KEY_FILE" "$CSR_FILE" "$EXT_FILE"
        '';
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/vault/data 0700 vault vault -"
  ];

  services.vault-server = {
    enable = true;
    package = pkgs.vault-bin;

    storageBackend = "raft";

    pluginDirectory = pkgs.vault-plugins;

    environmentFiles = [
      config.age.secrets."aws-kms.env".path
    ];

    settings = {
      # Raft integrated storage for HA
      storage.raft = {
        path = "/var/lib/vault/data";
        node_id = "vault-${host}";

        # Use Consul DNS to discover other vault servers
        retry_join = [
          {
            leader_api_addr = "https://active.vault.service.consul:8200";
            leader_ca_cert_file = vaultSecretDir + "vault-ca.pem";
          }
        ];
      };

      # Register with Consul for service discovery
      service_registration.consul = {
        address = "127.0.0.1:8500";
        service_tags = lib.concatStringsSep "," [
          "traefik.enable=true"
          "traefik.http.routers.vault-ui.rule=Host(`vault.local.${globals.domains.main}`)"
          "traefik.http.services.vault-ui.loadbalancer.server.scheme=https"
          "traefik.http.services.vault-ui.loadbalancer.serversTransport=insecure@file"
        ];
      };

      # Listeners
      listener = [
        # Primary listener on Nebula IP with TLS
        {
          tcp = {
            address = "${nebulaIp}:8200";
            tls_cert_file =
              lib.removeSuffix "key.pem.age" config.age.secrets."vault-server-key.pem".rekeyFile + "crt.pem";
            tls_key_file = config.age.secrets."vault-server-key.pem".path;
          };
        }
        # Localhost listener for CLI (no TLS)
        {
          tcp = {
            address = "127.0.0.1:8200";
            tls_disable = true;
          };
        }
      ];

      # API and cluster addresses
      api_addr = "https://${nebulaIp}:8200";
      cluster_addr = "https://${nebulaIp}:8201";
      disable_mlock = true;

      # Enable UI
      ui = true;

      # Telemetry for Prometheus
      telemetry = {
        disable_hostname = true;
        prometheus_retention_time = "30s";
      };

      seal.awskms = {
        region = "eu-north-1";
        kms_key_id = "alias/vault-unseal";
      };
    };
  };

  # Set VAULT_ADDR environment variable for convenience
  environment.variables = {
    VAULT_ADDR = "http://127.0.0.1:8200";
  };

  # Nebula firewall rules
  globals.nebula.mesh.hosts.${host} = {
    groups = [
      "vault-server"
      # for postgres secrets engine
      "postgres-client"
    ];
    firewall.inbound = [
      # Vault API (8200)
      {
        port = "8200";
        proto = "tcp";
        group = "vault-server";
      }
      {
        port = "8200";
        proto = "tcp";
        group = "vault-client";
      }
      {
        port = "8200";
        proto = "tcp";
        group = "nomad-client";
      }
      # Vault cluster communication (8201)
      {
        port = "8201";
        proto = "tcp";
        group = "vault-server";
      }
      # Traefik for the UI
      {
        port = "8200";
        proto = "tcp";
        group = "reverse-proxy";
      }
    ];
  };
}
