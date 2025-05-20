# Based on https://github.com/akirak/homelab/blob/master/profiles/intel-arc/default.nix
# Which was based on https://github.com/VTimofeenko/monorepo-machine-config/blob/4c1f85c700c45a5d3a8a38956194d2c97753b8ba/nixosConfigurations/neon/configuration/hw-acceleration.nix#L24
{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.hardware.gpu.nvidia;
in
{
  options.hardware.gpu.nvidia = with types; {
    enable = mkBoolOpt false "Enable NVIDIA GPU support";
  };

  config = mkIf cfg.enable {
    # TODO: Support...
  };
}
