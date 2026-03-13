{
  flake.features.utils.nixos =
    {
      config,
      pkgs,
      lib,
      ...
    }:
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
          lm_sensors
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
      system.activationScripts.diff = {
        supportsDryActivation = true;
        text = ''
          if [[ -e /run/current-system ]]; then
            ${lib.getExe pkgs.nvd} --color=always --nix-bin-dir=${config.nix.package}/bin diff /run/current-system "$systemConfig" || echo "FAILED TO GENERATE DIFF"
          fi
        '';
      };
    };
}
