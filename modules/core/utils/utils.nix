{
  flake.features.utils.nixos =
    { config, pkgs, ... }:
    {
      environment.systemPackages =
        with pkgs;
        [
          coreutils
          curl
          fd
          file
          findutils
          killall
          lsof
          pciutils
          usbutils
          unzip
          wget
          psmisc
          netcat
          traceroute
          tcpdump
        ]
        ++ (if config.hardware.nvidia.modesetting.enable then [ pkgs.btop-cuda ] else [ pkgs.btop ]);

      # Log diff when system update is applied
      # system.activationScripts.diff = {
      #   supportsDryActivation = true;
      #   text = ''
      #     ${pkgs.nvd}/bin/nvd --nix-bin-dir=${pkgs.nix}/bin diff /run/current-system "$systemConfig"
      #   '';
      # };
    };
}
