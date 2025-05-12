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
  cfg = config.hardware.gpu.intel-arc;
in
{
  options.hardware.gpu.intel-arc = with types; {
    enable = mkBoolOpt false "Enable Intel ARC support";
    device_id = mkOption {
      type = types.str;
      default = "22182";
      description = "The PCI ID of the Intel ARC device";
    };
  };

  config = mkIf cfg.enable {

    # imports = [
    #   (inputs.nixos-hardware.outPath + "/common/gpu/intel")
    # ];

    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver
        intel-ocl
        # nixos-unstable
        vpl-gpu-rt
        intel-media-sdk
        intel-compute-runtime
        intel-vaapi-driver
      ];
    };

    boot.kernelParams = [
      # Check the ID by running `lspci -k | grep -EA3 'VGA|3D|Display'`
      "i915.force_probe=${cfg.device_id}"
      "i915.enable_guc=3"
    ];

    environment.sessionVariables = {
      VDPAU_DRIVER = "va_gl";
      LIBVA_DRIVER_NAME = "iHD";
    };

    environment.systemPackages = with pkgs; [
      pciutils
      libva-utils
      intel-gpu-tools
    ];
  };
}
