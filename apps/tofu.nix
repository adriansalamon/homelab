{
  pkgs,
  globals,
  ...
}:
let
  inherit (pkgs.lib)
    getExe
    flip
    mapAttrsToList

    ;

  tailscaleConfig = {
    sites = flip mapAttrsToList globals.sites (
      name: site: {
        inherit name;
        lan_cidr = site.vlans.lan.cidrv4;
        dns_server = pkgs.lib.net.cidr.host 1 site.vlans.lan.cidrv4;
      }
    );

    internal_domains = [
      "local.${globals.domains.main}"
      "internal"
    ];

    inherit (globals) users domains;
  };

in
{
  type = "app";
  program = getExe (
    pkgs.writeShellApplication {
      name = "generate-json-globals";
      text = ''
        set -euo pipefail
        output_file=".terraform/tailscale-config.json"

        mkdir -p "$(dirname "$output_file")"
        cat > "$output_file" <<'EOF'
        ${builtins.toJSON tailscaleConfig}
        EOF

        echo "✓ Generated $output_file for OpenTofu" >&2

        # Start SSH tunnel for Consul
        echo "→ Starting SSH tunnel to Consul (localhost:15432 -> 10.64.32.5:8500)..." >&2
        ssh -N -L 15432:10.64.32.5:8500 nixos@10.64.32.5 &
        tunnel_pid=$!

        # Ensure tunnel is killed on exit
        cleanup() {
          echo "→ Closing SSH tunnel..." >&2
          kill "$tunnel_pid" 2>/dev/null || true
        }
        trap cleanup EXIT INT TERM

        # Wait for tunnel to be ready
        sleep 1

        echo "✓ SSH tunnel established" >&2

        tofu "$@"
      '';
    }
  );
}
