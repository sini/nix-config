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
        open = false;
        nvidiaSettings = false;
        nvidiaPersistenced = true; # TODO: Followup on https://github.com/NixOS/nixpkgs/issues/437066
        package = config.boot.kernelPackages.nvidiaPackages.beta;
      };
    };

}
