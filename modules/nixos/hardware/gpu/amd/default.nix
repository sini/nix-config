# Based on https://github.com/akirak/homelab/blob/master/profiles/intel-arc/default.nix
# Which was based on https://github.com/VTimofeenko/monorepo-machine-config/blob/4c1f85c700c45a5d3a8a38956194d2c97753b8ba/nixosConfigurations/neon/configuration/hw-acceleration.nix#L24
{
  config,
  pkgs,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.hardware.gpu.amd;
in
{
  options.hardware.gpu.amd = with types; {
    enable = mkBoolOpt false "Enable AMD GPU support";
  };

  config = mkIf cfg.enable {
    boot.initrd.kernelModules = [ "amdgpu" ];
    services.xserver.videoDrivers = [ "amdgpu" ];
    hardware.amdgpu = {
      opencl.enable = true;
      amdvlk.enable = true;
      initrd.enable = true;
    };

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    nixpkgs.config.rocmSupport = true;

    environment.systemPackages = with pkgs; [
      pciutils
      rocmPackages.rocminfo
      clinfo
      rocmPackages.clr.icd
      nvtopPackages.amd
      amdgpu_top
    ];
  };
}
