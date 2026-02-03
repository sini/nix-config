{ self, lib, ... }:
let
  inherit (lib) mkOption types;
  inherit (self.lib.modules) mkDeferredModuleOpt;

  serviceSubmodule =
    { name, ... }:
    {
      options = {
        name = mkOption {
          type = types.str;
          default = name;
          readOnly = true;
          internal = true;
        };

        requires = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "List of names of services required by this service";
        };

        excludes = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "List of names of services to exclude from this service";
        };

        nixidy = mkDeferredModuleOpt "A nixidy module for this Kubernetes service";
      };
    };
in
{
  options.flake.kubernetes.services = mkOption {
    type = types.lazyAttrsOf (types.submodule serviceSubmodule);
    default = { };
    description = "Kubernetes service definitions with their nixidy modules";
  };
}
