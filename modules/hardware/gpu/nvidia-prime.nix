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
              pciPath =
                xorgBusId:
                let
                  components = lib.drop 1 (lib.splitString ":" xorgBusId);
                  toHex = i: lib.toLower (lib.toHexString (lib.toInt i));

                  domain = "0000"; # Apparently the domain is practically always set to 0000
                  bus = lib.fixedWidthString 2 "0" (toHex (builtins.elemAt components 0));
                  device = lib.fixedWidthString 2 "0" (toHex (builtins.elemAt components 1));
                  function = builtins.elemAt components 2; # The function is supposedly a decimal number
                in
                "dri/by-path/pci-${domain}:${bus}:${device}.${function}-card";

              pCfg = config.hardware.nvidia.prime;
              igpuPath = pciPath pCfg.intelBusId;
              dgpuPath = pciPath pCfg.nvidiaBusId;
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
