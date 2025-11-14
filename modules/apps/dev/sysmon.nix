{ lib, ... }:
{
  flake.features.sysmon.home =
    { osConfig, pkgs, ... }:
    {

      home.packages = with pkgs; [
        ctop
        iotop-c
        sysstat
      ];

      programs = {
        btop = {
          enable = true;

          settings = {
            theme_background = false;
            vim_keys = true;
            shown_boxes = builtins.concatStringsSep " " [
              "cpu"
              "mem"
              "net"
              "proc"
              "gpu0"
            ];
            update_ms = 1000;
            cpu_single_graph = true;
            proc_per_core = true;
            proc_info_smaps = true;
            proc_filter_kernel = true;
            # Based on: https://github.com/Nerowy/Nix-files/blob/c3255e58fdab3985001873b1bd035f47ab688829/home-manager/programs/btop.nix
            # Without this it lists eeeeevvvverrrryyyyyy persistence bind mount...
            disks_filter =
              let
                excludeDirectories =
                  # retrieve all system level persited directories
                  (lib.flatten (
                    map
                      # map each persistence config to a list of persisted directories
                      (persistenceConfig: map (dir: dir.dirPath) persistenceConfig.directories)
                      # data from system's persistence configs
                      (builtins.attrValues osConfig.environment.persistence)
                  ))
                  ++ (lib.flatten (
                    map (persistenceConfig: map (f: f.file) persistenceConfig.files) (
                      builtins.attrValues osConfig.environment.persistence
                    )
                  ))
                  ++ [
                    "/boot"
                  ];
              in
              "exclude=${lib.concatStringsSep " " excludeDirectories}";
            swap_disk = false;
            only_physical = false;
            gpu_mirror_graph = false;
            io_mode = true;
          };
        };

        bottom = {
          enable = true;
          package = pkgs.bottom;
          settings = { };
        };
      };
    };
}
