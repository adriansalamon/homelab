let
  adrian = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICOfx4SWN/ygsiUkWWWRCFcTz/SBBRO0qKirHiYuvr3x asalamon@kth.se"
    "age1yubikey1qw8ddwxjsp2zdrajc5kk2m3ccv83f74yu3cjujfs8kfq823vqv6k2zyta6a"
  ];

  dbservers = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPLAq2TgrBskxDXs4b7eRQ1C67goy6SBWlDXsaEFTstp root@data" # data
  ];

  servers = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJYqfylrwJvl0S063jn7pzXYsqIXQlU45suN/sBeNNLa root@nixos" # nixos
  ];

in
{
  # `CF_DNS_API_TOKEN=...`
  "cloudflare-dns-api-token.env.age".publicKeys = adrian ++ servers;

  # Authelia secrets
  "authelia-jwt-secret.txt.age".publicKeys = adrian ++ servers;
  "authelia-storage-encryption-key.txt.age".publicKeys = adrian ++ servers;
  "authelia-session-secret.txt.age".publicKeys = adrian ++ servers;
  "authelia-smtp-password.txt.age".publicKeys = adrian ++ servers;
  "authelia-ldap-password.txt.age".publicKeys = adrian ++ servers;
  "authelia-jwks-key.key.age".publicKeys = adrian ++ servers;
  "authelia-hmac-secret.txt.age".publicKeys = adrian ++ servers;

  # OIDC clients

  # LDAP secrets
  "ldap-jwt-secret.txt.age".publicKeys = adrian ++ servers;
  "ldap-key-seed.txt.age".publicKeys = adrian ++ servers;
  "ldap-user-password.txt.age".publicKeys = adrian ++ servers;

  # Database secrets
  "postgres-password.txt.age".publicKeys = adrian ++ servers ++ dbservers;
  "redis-password.txt.age".publicKeys = adrian ++ servers ++ dbservers;
  "couchdb-password.txt.age".publicKeys = adrian ++ dbservers;
}
