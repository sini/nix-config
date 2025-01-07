{
  options,
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.hardware.nvidia;
in
{
  options.hardware.nvidia = with types; {
    enable = mkBoolOpt false "Enable drivers and patches for Nvidia hardware.";
  };

  config = mkIf cfg.enable {
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      modesetting.enable = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };

    environment = {
      variables = {
        CUDA_CACHE_PATH = "$XDG_CACHE_HOME/nv";
      };
      shellAliases = {
        nvidia-settings = "nvidia-settings --config='$XDG_CONFIG_HOME'/nvidia/settings";
      };
      sessionVariables.WLR_NO_HARDWARE_CURSORS = "1"; # Fix cursor rendering issue on wlr nvidia.
    };

    # Hyprland settings
    programs.hyprland.enableNvidiaPatches = true;
  };
}
