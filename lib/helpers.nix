_inputs: final: prev: {
  lib = prev.lib // {

    keepAttrs =
      attrs: keys:
      builtins.listToAttrs (
        map (k: {
          name = k;
          value = attrs.${k};
        }) keys
      );

    helpers = {
      generateWithEnv =
        envName:
        (
          {
            lib,
            decrypt,
            deps,
            ...
          }:
          ''
            echo -n "${envName}="
            ${decrypt} ${lib.escapeShellArg (lib.head deps).file}
          ''
        );
    };
  };
}
