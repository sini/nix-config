{
  flake.modules.nixos.gpu-nvidia-driver =
    {
      config,
      pkgs,
      ...
    }:
    {
      services.xserver.videoDrivers = [ "nvidia" ];

      hardware.graphics = {
        enable = true;
        extraPackages = with pkgs; [
          vaapiVdpau
          libvdpau
          libvdpau-va-gl
          nvidia-vaapi-driver
          vdpauinfo
          libva
          libva-utils
        ];
      };

      hardware.nvidia = {
        forceFullCompositionPipeline = true;
        modesetting.enable = true;
        powerManagement.enable = true;
        open = true;
        nvidiaSettings = false;
        nvidiaPersistenced = true;
        package = config.boot.kernelPackages.nvidiaPackages.beta;
      };
    };

}
