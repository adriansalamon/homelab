{ config, inputs, ... }:
{
  age.rekey = {
    inherit (inputs.self.secretsConfig) masterIdentities;

    storageMode = "local";
    hostPubkey = config.node.secretsDir + "/host.pub";
    generatedSecretsDir = inputs.self.outPath + "/secrets/generated/${config.node.name}";
    localStorageDir = inputs.self.outPath + "/secrets/rekeyed/${config.node.name}";
  };
}
