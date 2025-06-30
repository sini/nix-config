{
  flake.modules.nixos.gpu-nvidia-prime =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [
        ./intel.nix
        ./nvidia.nix
      ];

      config =
        let
          formatPciId =
            id: "PCI:" + (lib.strings.replaceStrings [ "." ] [ ":" ] (lib.strings.removePrefix "0000:" id));

          nvidiaCard = lib.lists.findFirst (
            card: card.vendor.name == "nVidia Corporation"
          ) null config.facter.report.hardware.graphics_card;

          nvidiaBusID = if nvidiaCard != null then formatPciId nvidiaCard.sysfs_bus_id else "PCI:1:0:0";

          intelCard = lib.lists.findFirst (
            card: card.vendor.name == "Intel Corporation"
          ) null config.facter.report.hardware.graphics_card;

          intelBusID = if intelCard != null then formatPciId intelCard.sysfs_bus_id else "PCI:0:2:0";
        in
        {

          services.xserver.videoDrivers = [ "modesetting" ];

          hardware.nvidia = {
            prime = {
              offload = {
                enable = true;
                enableOffloadCmd = true;
              };
              intelBusId = intelBusID;
              nvidiaBusId = nvidiaBusID;
            };
            dynamicBoost.enable = true;
          };

          # Set up a udev rule to create named symlinks for the pci paths.
          #
          # This is necessary because wlroots splits the DRM_DEVICES on
          # `:`, which is part of the pci path.
          services.udev.packages =
            let
              igpuPath = intelCard.sysfs_bus_id;
              dgpuPath = nvidiaCard.sysfs_bus_id;
            in
            [
              (pkgs.writeTextDir "lib/udev/rules.d/61-gpu-offload.rules" ''
                SYMLINK=="${igpuPath}", SYMLINK+="dri/igpu1"
                SYMLINK=="${dgpuPath}", SYMLINK+="dri/dgpu1"
              '')
            ];
        };
    };

}
