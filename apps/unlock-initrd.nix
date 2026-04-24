{
  pkgs,
  nixosConfigurations,
  decryptIdentity,
  globals,
}:
let
  inherit (pkgs.lib)
    attrNames
    concatStringsSep
    filterAttrs
    getExe
    mapAttrsToList
    ;

  unlockableHosts = filterAttrs (
    _: cfg: cfg.config.boot.initrd.remoteUnlock.enable
  ) nixosConfigurations;

  hostIp =
    name: cfg:
    if cfg.config.boot.initrd.remoteUnlock.nebula then
      globals.nebula.mesh.hosts.${name}.ipv4
    else
      cfg.config.node.publicIp;

  caseEntry =
    name: cfg:
    let
      ip = hostIp name cfg;
      keyFile = cfg.config.age.secrets.zroot-encryption-key.rekeyFile;
    in
    ''
      ${name})
        target_ip=${ip}
        zfs_keyfile=${keyFile}
        ;;'';
in
{
  type = "app";
  program = getExe (
    pkgs.writeShellApplication {
      name = "unlock-initrd";
      runtimeInputs = with pkgs; [
        openssh
        rage
        age-plugin-yubikey
      ];
      text = ''
        hostname="''${1:-}"

        if [[ -z "$hostname" ]]; then
          echo "Usage: unlock-initrd <hostname>"
          echo ""
          echo "Available hosts:"
          ${concatStringsSep "\n" (map (n: "echo '  ${n}'") (attrNames unlockableHosts))}
          exit 1
        fi

        case "$hostname" in
          ${concatStringsSep "\n  " (mapAttrsToList caseEntry unlockableHosts)}
          *)
            echo "Unknown host: $hostname"
            echo "Available: ${concatStringsSep " " (attrNames unlockableHosts)}"
            exit 1
            ;;
        esac

        echo "Decrypt secret for $hostname..."
        passphrase=$(PATH="$PATH:${pkgs.age-plugin-yubikey}/bin" \
          ${pkgs.rage}/bin/rage -d -i ${decryptIdentity} "$zfs_keyfile")

        # base64-encode so the passphrase can be safely embedded in the SSH string
        passphrase_b64=$(printf '%s' "$passphrase" | base64)

        echo "Connecing to target over ssh (ssh -p 2222 root@$target_ip)..."
        ssh -p 2222 "root@$target_ip" "
          tmpfile=\$(mktemp)
          printf '%s' \"''${passphrase_b64}\" | base64 -d > \"\$tmpfile\"
          zfs list -H -o name,keystatus,keylocation \
            | while IFS=\$'\t' read -r name keystatus keylocation; do
                if [ \"\$keystatus\" = unavailable ] && [ \"\$keylocation\" = prompt ]; then
                  echo \"Loading key for \$name...\"
                  zfs load-key -L \"file://\$tmpfile\" \"\$name\"
                fi
              done
          rm -f \"\$tmpfile\"
          systemctl restart zfs-import-zroot.service
        "
        echo "Done — $hostname should finish booting shortly."
      '';
    }
  );
}
