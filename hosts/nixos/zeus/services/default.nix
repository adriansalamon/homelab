{ ... }:
{
  imports = [
    ./redis.nix
    ./postgres.nix
    ./couchdb.nix
    ./homepage.nix
    ./ntfy.nix
  ];
}
