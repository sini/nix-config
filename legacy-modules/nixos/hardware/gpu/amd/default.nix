# Based on https://github.com/akirak/homelab/blob/master/profiles/intel-arc/default.nix
# Which was based on https://github.com/VTimofeenko/monorepo-machine-config/blob/4c1f85c700c45a5d3a8a38956194d2c97753b8ba/nixosConfigurations/neon/configuration/hw-acceleration.nix#L24
{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
with lib.custom;
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
    hardware = {
      amdgpu = {
        opencl.enable = true;
        amdvlk.enable = false;
        # Note: we disable amdvlk for now, as open drivers are preferred -- left for reference
        # amdvlk = {
        #   enable = true;
        #   support32Bit = true;
        # };
        initrd.enable = true;
      };

      graphics = {
        enable = true;
        enable32Bit = true;
        extraPackages = with pkgs; [
          vaapiVdpau
          libva
          libvdpau-va-gl
          vulkan-loader
          vulkan-validation-layers
          vulkan-extension-layer
          rocmPackages.clr.icd
        ];
      };

    };
    # nixpkgs.config.rocmSupport = true;

    # environment.variables = {
    #   AMD_VULKAN_ICD = "RADV"; # Force RADV when amdvlk is enabled
    #   # NOTE: nixos manual says you can also use radeon_icd.json to force radv, here's the values for amdvlk for reference
    #   #VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/amd_icd64.json";
    #   #VK_DRIVER_FILES = "/run/opengl-driver/share/vulkan/icd.d/amd_icd64.json";
    # };

    environment.systemPackages = with pkgs; [
      pciutils
      rocmPackages.rocminfo
      clinfo
      nvtopPackages.amd
      amdgpu_top
      vulkan-tools
    ];

  };
}
