{
  profiles,
  globals,
  lib,
  inputs,
  ...
}:
let
  inherit (lib)
    unique
    mapAttrsToList
    genAttrs'
    ;

  dbUsers = unique (mapAttrsToList (_: { owner, ... }: owner) globals.databases);
  generatedDir = inputs.self.outPath + "/secrets/generated/postgres";
in
{
  imports = [
    profiles.services.patroni
  ];

  age.secrets = genAttrs' dbUsers (user: {
    name = "${user}-postgres-password";
    value = {
      rekeyFile = "${generatedDir}/${user}-postgres-password.age";
      generator.script = "alnum";
      intermediary = true; # we don't keep these on the host
    };
  });
}
