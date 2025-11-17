{
  pkgs,
  inputs,
  decryptIdentity,
}:
let
  inherit (pkgs.lib)
    concatStringsSep
    getExe
    groupBy
    mapAttrsToList
    ;

  nomadHomeConfig = inputs.self.homeConfigurations."nomad".config;

  decryptSecret = (
    secret:
    if (secret.hashFile != null) then
      ''
        cat ${secret.hashFile} | sed -e ':a' -e '$!N' -e '$!ba' -e 's/\n/\\n/g'
      ''
    else
      ''
        PATH="$PATH:${pkgs.age-plugin-yubikey}/bin" \
        ${pkgs.rage}/bin/rage -d -i ${decryptIdentity} ${secret.rekeyFile} | sed -e ':a' -e '$!N' -e '$!ba' -e 's/\n/\\n/g'
      ''
  );

  secrets = mapAttrsToList (name: cfg: cfg // { inherit name; }) nomadHomeConfig.age.secrets;

  # Group secrets by nomadPath
  secretsByPath = groupBy (s: s.nomadPath) secrets;
in
{
  type = "app";
  program = getExe (
    pkgs.writeShellApplication {
      name = "provision-nomad-secrets";
      runtimeInputs = with pkgs; [
        nomad
        rage
        jq
      ];
      text =
        let
          uploadSecret =
            nomadPath: secrets:
            let
              decryptSecrets = concatStringsSep "\n" (
                map (secret: ''
                  echo "Decrypting ${secret.name}"
                  secret=$(${decryptSecret secret})
                  name=$(echo "${secret.name}" | sed 's/-/_/g' | sed -E 's/[^_]+_(.+)/\1/g')
                  echo "Uploading to $name"
                  printf "%s\n" "$name = \"$secret\"" >> "$tmpfile"
                '') secrets
              );
            in
            ''
              echo "Uploading to ${nomadPath}"
              # Decrypt all secrets
              tmpfile=$(mktemp)
              echo "items = {" > "$tmpfile"
              ${decryptSecrets}
              echo "}" >> "$tmpfile"

              cat "$tmpfile" | ${pkgs.nomad}/bin/nomad var put -in hcl -force ${nomadPath} -
            '';

        in
        ''
          set -euo pipefail

          # Help text
          if [[ "''${1:-}" == "-h" || "''${1:-}" == "--help" ]]; then
            echo "Usage: provision-nomad-secrets"
            echo ""
            echo "Uploads decrypted age secrets to Nomad variables"
            exit 0
          fi

          echo "Uploading secrets to Nomad..."
          echo ""

          ${concatStringsSep "\n" (mapAttrsToList uploadSecret secretsByPath)}

          echo ""
          echo "✓ Secret provisioning complete!"
        '';
    }
  );
}
