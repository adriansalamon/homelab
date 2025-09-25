{ inputs, self, ... }:
{
  imports = [ inputs.agenix-rekey.flakeModule ];

  flake = {
    secretsConfig = {
      masterIdentities = [
        {
          identity = ../secrets/yubikey-identity.pub;
          pubkey = "age1yubikey1qw8ddwxjsp2zdrajc5kk2m3ccv83f74yu3cjujfs8kfq823vqv6k2zyta6a";
        }
        {
          identity = ../secrets/yubikey-identity-backup.pub;
          pubkey = "age1yubikey1q0wmqzjaxwgndf94hd7t37dx7wd45qwwk0r7zfytkasd6f5lvc70w89lwgg";
        }
      ];
    };
  };

  perSystem =
    { ... }:
    {
      agenix-rekey.nixosConfigurations = self.nodes;
    };
}
