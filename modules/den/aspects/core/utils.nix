{ den, ... }:
{
  den.aspects.utils = den.lib.perHost {
    os =
      { pkgs, ... }:
      {
        environment.systemPackages = with pkgs; [
          btop
          coreutils
          curl
          fd
          file
          findutils
          killall
          unzip
          wget
          netcat
          tcpdump
        ];
      };

    nixos =
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
            lm_sensors
            lsof
            pciutils
            usbutils
            psmisc
            traceroute
          ]
          ++ lib.optional config.hardware.nvidia.modesetting.enable pkgs.btop-cuda;

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
  };
}
