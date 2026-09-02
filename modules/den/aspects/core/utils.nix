{
  den.aspects.core.utils = {
    os =
      { pkgs, ... }:
      {
        environment.systemPackages = [
          # Absent, and its absence is SILENT: `x | bc` on a host without bc emits
          # nothing, so an arithmetic pipeline reads 0 rather than failing. Measured
          # 2026-09-02 — a latency probe reported 0.00s for every sample.
          pkgs.bc
          pkgs.btop
          # Absent, and the workaround was re-deriving its /nix/store path by hand
          # each time it was wanted.
          pkgs.cmark-gfm
          pkgs.coreutils
          pkgs.curl
          pkgs.fd
          pkgs.file
          pkgs.findutils
          pkgs.killall
          pkgs.unzip
          pkgs.wget
          pkgs.netcat
          pkgs.tcpdump
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
        environment.systemPackages = [
          pkgs.lm_sensors
          pkgs.lsof
          pkgs.pciutils
          pkgs.usbutils
          pkgs.psmisc
          pkgs.traceroute
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
