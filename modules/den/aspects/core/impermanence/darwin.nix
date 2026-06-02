# Dummy persistence options for Darwin so modules that reference
# osConfig.environment.persistence don't error out.
{ lib, ... }:
{
  den.aspects.core.impermanence.darwin = {
    darwin = _: {
      options.environment.persistence = lib.mkOption {
        type = lib.types.anything;
        default = { };
        description = "Dummy persistence option for Darwin (no-op).";
      };

      config = {
        home-manager.sharedModules = [
          {
            options.home.persistence = lib.mkOption {
              type = lib.types.anything;
              default = { };
              description = "Dummy persistence option for Darwin (no-op).";
            };
          }
        ];
      };
    };
  };
}
