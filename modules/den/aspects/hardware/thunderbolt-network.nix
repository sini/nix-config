# Thunderbolt network hardware support.
#
# Auto-discovers thunderbolt controllers from facter and creates systemd.network.links
# with predictable interface names derived from PCI topology plus tb<N> aliases.
{ ... }:
{
  den.aspects.hardware.thunderbolt-network = {
    nixos =
      { config, lib, ... }:
      let
        # Sorted by PCI bus ID for deterministic interface numbering
        thunderboltControllers =
          let
            filtered = lib.filter (c: c.driver == "thunderbolt") config.facter.report.hardware.usb_controller;
          in
          lib.sort (a: b: a.sysfs_bus_id < b.sysfs_bus_id) filtered;

        parseBusId =
          busId:
          let
            parts = lib.splitString ":" busId;
            busHex = lib.elemAt parts 1;
            devFunc = lib.splitString "." (lib.elemAt parts 2);
            slot = lib.elemAt devFunc 0;
            func = lib.elemAt devFunc 1;
          in
          {
            busDec = toString (lib.fromHexString busHex);
            slotDec = toString (lib.fromHexString slot);
            inherit func;
          };

        mkPredictableName =
          busId:
          let
            p = parseBusId busId;
          in
          "enp${p.busDec}s${p.slotDec}f${p.func}";

        linkRules = lib.imap0 (
          idx: controller:
          let
            pciPath = "pci-${controller.sysfs_bus_id}";
            predictableName = mkPredictableName controller.sysfs_bus_id;
            alias = "tb${toString idx}";
          in
          {
            name = "20-thunderbolt-port-${toString idx}";
            value = {
              matchConfig = {
                Path = pciPath;
                Driver = "thunderbolt-net";
              };
              linkConfig = {
                Name = predictableName;
                Alias = alias;
                AlternativeName = alias;
              };
            };
          }
        ) thunderboltControllers;
      in
      lib.mkIf (thunderboltControllers != [ ]) {
        boot = {
          kernelParams = [ "pcie=pcie_bus_perf" ];
          kernelModules = [
            "thunderbolt"
            "thunderbolt-net"
          ];
        };

        systemd.network.links = lib.listToAttrs linkRules;
      };
  };
}
