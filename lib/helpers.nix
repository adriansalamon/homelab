_inputs: final: prev: {
  lib = prev.lib // {
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
