{
  pkgs,
  ...
}:
let
  inherit (pkgs.lib)
    getExe
    ;

in
{
  type = "app";
  program = getExe (
    pkgs.writeShellApplication {
      name = "tofu";
      text = ''
        set -euo pipefail
        # Start SSH tunnel for Consul
        echo "→ Starting SSH tunnel to Consul (localhost:15432 -> 10.64.32.5:8500)..." >&2
        ssh -N -L 15432:127.0.0.1:8500 nixos@10.64.32.5 &
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
