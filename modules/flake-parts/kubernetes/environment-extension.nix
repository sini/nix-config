{
  self,
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
  inherit (self.lib.kubernetes-services) kubernetesConfigType;
in
{
  options.environments = mkOption {
    type = types.attrsOf (
      types.submodule {
        options.kubernetes = mkOption {
          type = kubernetesConfigType;
          default = { };
          description = "Kubernetes-specific configuration for this environment";
        };
      }
    );
  };
}
