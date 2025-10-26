{
  pkgs,
  globals,
  secrets,
  decryptIdentity,
}:
let
  inherit (pkgs.lib)
    concatStringsSep
    getExe
    mapAttrsToList
    unique
    ;

  # Extract unique database owners (users)
  dbUsers = unique (mapAttrsToList (_: { owner, ... }: owner) globals.databases);

  decryptSecret = secretPath: ''
    PATH="$PATH:${pkgs.age-plugin-yubikey}/bin" \
    ${pkgs.rage}/bin/rage -d -i ${decryptIdentity} ${secretPath} | tr -d '\n'
  '';

in
{
  type = "app";
  program = getExe (
    pkgs.writeShellApplication {
      name = "provision-postgres";
      runtimeInputs = with pkgs; [
        postgresql
        rage
        dnsutils
      ];
      text =
        let
          psqlCommand = ''PGPASSWORD="$pass" ${pkgs.postgresql}/bin/psql -h "$HOST" -U "postgres" -tAc'';
        in
        ''
          set -euo pipefail

          # Help text
          if [[ "''${1:-}" == "-h" || "''${1:-}" == "--help" ]]; then
            echo "Usage: provision-postgres [HOST_OR_IP]"
            echo ""
            echo "Provisions databases and users in PostgreSQL"
            echo "Default host: primary.homelab-cluster.service.consul"
            exit 0
          fi

          # Default host
          if [[ "''${1:-}" == "" ]]; then
            HOST=$(${pkgs.dnsutils}/bin/dig +short primary.homelab-cluster.service.consul | head -n 1)
          else
            HOST="$1"
          fi

          echo "Provisioning PostgreSQL on $HOST"
          echo ""

          echo "Decrypt master postgres password..."
          pass=$(${decryptSecret "${secrets.patroni-superuser-password.rekeyFile}"})

          echo "Creating roles and setting passwords..."

          # Provision users/roles with passwords
          ${concatStringsSep "\n" (
            map (user: ''
              echo " - ${user}"

              # Create role if it doesn't exist
              ${psqlCommand} "SELECT 1 FROM pg_roles WHERE rolname='${user}'" | grep -q 1 || ${psqlCommand} "CREATE USER ${user}"

              # Decrypt password and set it
              password=$(${decryptSecret "${secrets."${user}-postgres-password".rekeyFile}"})
              password_escaped="''${password//\'/\'\'}"
              ${psqlCommand} "ALTER ROLE ${user} WITH PASSWORD '$password_escaped'"
            '') dbUsers
          )}

          echo ""
          echo "Creating databases..."

          # Provision databases
          ${concatStringsSep "\n" (
            mapAttrsToList (
              name:
              { owner, ... }:
              ''
                echo " - ${name} (owner: ${owner})"
                ${psqlCommand} "SELECT 1 FROM pg_database WHERE datname='${name}'" | grep -q 1 || ${psqlCommand} 'CREATE DATABASE "${name}"'
                ${psqlCommand} 'ALTER DATABASE "${name}" OWNER TO "${owner}";'
              ''
            ) globals.databases
          )}

          echo ""
          echo "✓ Provisioning complete!"
        '';
    }
  );
}
