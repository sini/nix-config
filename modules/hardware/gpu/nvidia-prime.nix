{
  flake.modules.nixos.gpu-nvidia-prime =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      config =
        let
          formatPciId =
            id: "PCI:" + (lib.strings.replaceStrings [ "." ] [ ":" ] (lib.strings.removePrefix "0000:" id));

          nvidiaCard = lib.lists.findFirst (
            card: card.vendor.name == "nVidia Corporation"
          ) null config.facter.report.hardware.graphics_card;

          nvidiaBusID = if nvidiaCard != null then formatPciId nvidiaCard.sysfs_bus_id else "PCI:1:0:0";

          amdCard = lib.lists.findFirst (
            card: card.vendor.name == "ATI Technologies Inc"
          ) null config.facter.report.hardware.graphics_card;

          amdBusID = if amdCard != null then formatPciId amdCard.sysfs_bus_id else "";

          intelCard = lib.lists.findFirst (
            card: card.vendor.name == "Intel Corporation"
          ) null config.facter.report.hardware.graphics_card;

          intelBusID = if intelCard != null then formatPciId intelCard.sysfs_bus_id else "";
        in
        {
          hardware.nvidia = {
            powerManagement.finegrained = true;
            prime = {
              offload = {
                enable = true;
                enableOffloadCmd = true;
              };
              intelBusId = intelBusID;
              amdgpuBusId = amdBusID;
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
              icard = if intelCard != null then intelCard else amdCard;
            in
            lib.optionals (icard != null) [
              (pkgs.writeTextDir "lib/udev/rules.d/61-gpu-offload.rules" ''
                SYMLINK=="dri/by-path/pci-${icard.sysfs_bus_id}-card", SYMLINK+="dri/igpu1"
                SYMLINK=="dri/by-path/pci-${nvidiaCard.sysfs_bus_id}-card", SYMLINK+="dri/dgpu1"
              '')
            ];
        };
    };

}
