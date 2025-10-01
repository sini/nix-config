{
  flake.aspects.gpu-nvidia-driver.nixos =
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
        nvidiaPersistenced = false; # TODO: Followup on https://github.com/NixOS/nixpkgs/issues/437066
        package = config.boot.kernelPackages.nvidiaPackages.beta;
      };
    };

}
