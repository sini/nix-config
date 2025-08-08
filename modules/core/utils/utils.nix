{
  flake.modules.nixos.utils =
    { config, pkgs, ... }:
    {
      programs.dconf.enable = true;

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
          unzip
          wget
          psmisc
        ]
        ++ (if config.hardware.nvidia.modesetting.enable then [ pkgs.btop-cuda ] else [ pkgs.btop ]);
    };
}
