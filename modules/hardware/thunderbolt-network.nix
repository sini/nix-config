# Thunderbolt hardware support.
#
# Auto-discovers thunderbolt controllers from facter and creates stable
# device names (tb0, tb1, ...) via systemd.network.links. The PCI path
# comes from facter, so no hardcoding is needed per-host.
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

        # Generate link rename rules: pci-<bus_id> → tb<index>
        linkRules = lib.imap0 (
          idx: controller:
          let
            pciPath = "pci-${controller.sysfs_bus_id}";
            name = "tb${toString idx}";
          in
          {
            name = "20-thunderbolt-port-${toString idx}";
            value = {
              matchConfig = {
                Path = pciPath;
                Driver = "thunderbolt-net";
              };
              linkConfig = {
                Name = name;
                Alias = name;
                AlternativeName = name;
              };
            };
          }
        ) thunderboltControllers;
      in
      lib.mkIf (thunderboltControllers != [ ]) {
        boot = {
          kernelParams = [
            "pcie=pcie_bus_perf"
          ];
          kernelModules = [
            "thunderbolt"
            "thunderbolt-net"
          ];
        };

        systemd.network.links = lib.listToAttrs linkRules;
      };
  };
}
