{
  lib,
  config,
  inputs,
  ...
}:
let
  isNixosConfiguration = config ? networking.hostName;
  target = if isNixosConfiguration then config.networking.hostName else config.home.username;
in
{
  age.rekey = {
    inherit (inputs.self.secretsConfig) masterIdentities;

    storageMode = "local";
    hostPubkey = config.node.secretsDir + "/host.pub";
    generatedSecretsDir = inputs.self.outPath + "/secrets/generated/${config.node.name}";
    localStorageDir = inputs.self.outPath + "/secrets/rekeyed/${config.node.name}";
  };

  # I like passphrases to have a dash delimiter
  age.generators.passphrase = lib.mkForce (
    { pkgs, ... }: "${pkgs.xkcdpass}/bin/xkcdpass --numwords=6 --delimiter='-'"
  );

  # the default ssh-ed25519 generator does not work on MacOS
  age.generators.ssh-ed25519 = lib.mkForce (
    {
      lib,
      name,
      pkgs,
      ...
    }:
    ''
      TMPFILE=$(mktemp)
      ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" -C ${lib.escapeShellArg "${target}:${name}"} -f "$TMPFILE" <<<y >/dev/null 2>&1
      cat "$TMPFILE"
      rm "$TMPFILE" "$TMPFILE.pub"
    ''
  );
}
