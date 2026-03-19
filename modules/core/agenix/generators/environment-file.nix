# Generate an environment file with multiple KEY=value pairs.
# settings.keys: list of variable names that map to dependencies.
{
  features.agenix-generators.system =
    { lib, ... }:
    {
      age.generators.environment-file =
        {
          decrypt,
          deps,
          secret,
          ...
        }:
        let
          keys = secret.settings.keys;
          pairs = lib.lists.zipListsWith (key: dep: { inherit key dep; }) keys deps;
        in
        lib.strings.concatStringsSep "; " (
          map (
            pair: "echo \"${lib.escapeShellArg pair.key}=$(${decrypt} ${lib.escapeShellArg pair.dep.file})\""
          ) pairs
        );
    };
}
