{
  inputs,
  lib,
  helpers,
  ...
}:
let
  inherit (lib) foldlAttrs;

  inherit (inputs.self.nomadConfigurations."homelab".config.age) secrets;

  grouped = foldlAttrs (
    acc: name: secret:
    let
      path = secret.nomadPath;
      existing = acc.${path} or [ ];
    in
    acc // { ${path} = existing ++ [ { inherit name secret; } ]; }
  ) { } secrets;

  pathToName = path: lib.replaceStrings [ "/" ] [ "_" ] path;
  sopsFile = ref: lib.head (lib.splitString "#" (lib.removePrefix "ref+sops://" ref));

  # Extract job name from path like "nomad/jobs/grafana" -> "grafana"
  jobNameFromPath = path: lib.last (lib.splitString "/" path);

  # Parse SOPS lastmodified timestamp and convert to Unix epoch
  # Input format: "2026-04-06T23:18:31Z"
  # Output: Unix timestamp as integer
  sopsTimestampToEpoch =
    sopsFilePath:
    let
      yamlContent = builtins.readFile sopsFilePath;
      lines = lib.splitString "\n" yamlContent;
      lastmodifiedLine = lib.findFirst (line: lib.hasPrefix "    lastmodified:" line) null lines;

      isoTimestamp =
        if lastmodifiedLine != null then
          let
            withoutPrefix = lib.removePrefix "    lastmodified: \"" lastmodifiedLine;
            withoutSuffix = lib.removeSuffix "\"" withoutPrefix;
          in
          withoutSuffix
        else
          "1970-01-01T00:00:00Z";
    in
    helpers.iso8601ToUnix isoTimestamp;
in
{

  terraform.required_providers.sops = {
    source = "carlpett/sops";
    version = "1.4.1";
  };

  provider.sops = { };

  ephemeral.sops_file = lib.mapAttrs' (
    path: entries:
    let
      # All entries in a group share the same sops file, so grab from the first
      source_file = sopsFile (lib.head entries).secret.sopsRef;
    in
    lib.nameValuePair (pathToName path) {
      inherit source_file;
    }
  ) grouped;

  # One vault_kv_secret_v2 per group, with all secrets
  resource.vault_kv_secret_v2 = lib.mapAttrs' (
    path: entries:
    let
      resName = pathToName path;
      jobName = jobNameFromPath path;

      # Check if we have any hashFile entries
      hashFileEntries = lib.filter (e: e.secret.hashFile != null) entries;
      hasHashFiles = hashFileEntries != [ ];

      # Build a map of hashFile secrets
      hashFileMap = lib.foldl' (
        acc: entry: acc // { "${entry.secret.nomadName}" = builtins.readFile entry.secret.hashFile; }
      ) { } hashFileEntries;

      # Get version from SOPS file's lastmodified timestamp
      sopsFilePath = sopsFile (lib.head entries).secret.sopsRef;
      version = sopsTimestampToEpoch sopsFilePath;
    in
    lib.nameValuePair resName {
      mount = "\${vault_mount.kvv2.path}";
      # Vault path: secret/data/default/{job-name}
      name = "default/${jobName}";
      # If we have hashFiles, merge them in using Terraform's merge() function
      data_json_wo =
        if hasHashFiles then
          "\${jsonencode(merge(ephemeral.sops_file.${resName}.data, ${builtins.toJSON hashFileMap}))}"
        else
          "\${jsonencode(ephemeral.sops_file.${resName}.data)}";
      # Version is Unix timestamp from SOPS file's lastmodified field
      data_json_wo_version = version;
    }
  ) grouped;
}
