{ lib, pkgs, ... }:
{

  environment.persistence."/state".directories = lib.singleton {
    directory = "/var/lib/coredns";
    mode = "755";
    user = "blocker";
  };

  users.groups.blocker = { };
  users.users.blocker = {
    isSystemUser = true;
    group = "blocker";
  };

  services.coredns.package = pkgs.coredns.override {
    externalPlugins = lib.singleton {
      name = "blocker";
      repo = "github.com/adriansalamon/blocker";
      version = "023895b530f1843ffc0a96d1428e1f3f6da507a6";
      position.before = "forward";
    };
    vendorHash = "sha256-TCmCCu5GlzXcoQSshq/rGDI+2Uv5t5ZIwwqsz5PceDA=";
  };

  systemd.services.blocklist-downloader = {
    description = "Download and merge DNS blocklists";
    requires = [ "coredns.service" ];
    script =
      let
        curlExe = lib.getExe pkgs.curl;
      in
      ''
        #!/usr/bin/env bash
        set -eu

        BLOCKLIST_DIR="/var/lib/coredns"
        BLOCKLIST_FILE="$BLOCKLIST_DIR/blocklist.txt"
        TEMP_DIR=$(mktemp -d)

        trap 'rm -rf "$TEMP_DIR"' EXIT

        echo "Starting DNS blocklist download..."

        # Download blocklists
        echo "Downloading OISD Big list..."
        ${curlExe} -s -L "https://big.oisd.nl/" \
            -o "$TEMP_DIR/oisd.abp" || true

        echo "Downloading StevenBlack hosts list..."
        ${curlExe} -s -L "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" \
            -H "accept: text/plain" \
            -o "$TEMP_DIR/stevenblack.hosts" || true

        cat "$TEMP_DIR/stevenblack.hosts" | grep -E '^0.0.0.0' | sed 's#0.0.0.0 ##g' | sed 's#^#||#g' | sed 's#$#^#g' > "$TEMP_DIR/stevenblack.abp"

        # Combine all lists
        echo "Merging blocklists..."
        cat "$TEMP_DIR"/*.abp | grep -E '^\|\|' > "$TEMP_DIR/merged.list" 2>/dev/null || true

        # Move to final location
        mv "$TEMP_DIR/merged.list" "$BLOCKLIST_FILE"

        echo "Blocklist update completed successfully"
        echo "Total entries: $(wc -l < "$BLOCKLIST_FILE")"
      '';
    serviceConfig = {
      Type = "oneshot";
      User = "blocker";
    };
  };

  systemd.timers.blocklist-downloader = {
    description = "Daily DNS blocklist download timer";
    timerConfig = {
      OnCalendar = "daily";
      OnBootSec = "5min";
      Persistent = true;
    };
    wantedBy = [ "timers.target" ];
  };

}
