{ lib, ... }:
{
  den.aspects.apps.dev.shell.btop = {
    homeManager =
      { osConfig, ... }:
      {
        programs.btop = {
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
            disks_filter =
              let
                excludeDirectories =
                  (lib.flatten (
                    map (persistenceConfig: map (dir: dir.dirPath) persistenceConfig.directories) (
                      builtins.attrValues (osConfig.environment.persistence or { })
                    )
                  ))
                  ++ (lib.flatten (
                    map (persistenceConfig: map (f: f.file) persistenceConfig.files) (
                      builtins.attrValues (osConfig.environment.persistence or { })
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
      };
  };
}
