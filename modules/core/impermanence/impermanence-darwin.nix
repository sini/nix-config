# Darwin Compatibility
# ====================
# Registers dummy persistence options for Darwin (NixOS impermanence not loaded).
# Prevents errors in modules referencing osConfig.environment.persistence.
{
  features.impermanence.darwin =
    { lib, ... }:
    {
      # Dummy environment.persistence (prevents option reference errors)
      options.environment.persistence = lib.mkOption {
        type = lib.types.anything;
        default = { };
        description = "Dummy persistence option for Darwin (no-op).";
      };

      config = {
        impermanence.enable = false; # Explicitly disable impermanence on Darwin (no-op)
        home-manager.sharedModules = [
          {
            # Dummy home.persistence (supports impermanence home key without HM module)
            options.home.persistence = lib.mkOption {
              type = lib.types.anything;
              default = { };
              description = "Dummy persistence option for Darwin (no-op).";
            };
          }
        ];
      };
    };
}
