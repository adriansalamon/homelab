{ ... }:
{
  imports = [
    ./redis.nix
    ./postgres.nix
    ./couchdb.nix
  ];
}
