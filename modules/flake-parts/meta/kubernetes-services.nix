{ self, lib, ... }:
let
  inherit (lib) mkOption;
  inherit (self.lib.modules) kubernetesType;
in
{
  options.flake.kubernetes = mkOption {
    type = kubernetesType;
    default = { };
    description = "Global Kubernetes configuration";
  };
}
