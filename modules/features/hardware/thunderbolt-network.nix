# Thunderbolt network hardware support.
#
# Auto-discovers thunderbolt controllers from facter and creates systemd.network.links
# with predictable interface names derived from PCI topology (matching the kernel's
# stable naming scheme) plus tb<N> aliases for convenience.
#
# Example: PCI bus 0xc7, function 5 → Name=enp199s0f5, Alias=tb0
{
  features.thunderbolt-network = {
    linux =
      {
        config,
        lib,
        ...
      }:
      let
        # Discover thunderbolt controllers from facter, sorted by PCI bus ID for deterministic ordering
        thunderboltControllers =
          let
            filtered = lib.filter (c: c.driver == "thunderbolt") config.facter.report.hardware.usb_controller;
          in
          lib.sort (a: b: a.sysfs_bus_id < b.sysfs_bus_id) filtered;

        # Parse PCI bus ID "0000:c7:00.5" into components for predictable naming
        parseBusId =
          busId:
          let
            # Split "0000:c7:00.5" → ["0000" "c7" "00.5"]
            parts = lib.splitString ":" busId;
            busHex = lib.elemAt parts 1;
            devFunc = lib.splitString "." (lib.elemAt parts 2);
            slot = lib.elemAt devFunc 0;
            func = lib.elemAt devFunc 1;
          in
          {
            # Convert hex bus number to decimal for the kernel naming scheme
            busDec = toString (lib.fromHexString busHex);
            slotDec = toString (lib.fromHexString slot);
            inherit func;
          };

        # Derive kernel predictable name: enp<bus>s<slot>f<func>
        mkPredictableName =
          busId:
          let
            p = parseBusId busId;
          in
          "enp${p.busDec}s${p.slotDec}f${p.func}";

        # Generate link rules with predictable names and tb<N> aliases
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
