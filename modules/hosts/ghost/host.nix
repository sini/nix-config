{ inputs, config, ... }:
{
  flake.hosts.ghost = {
    ipv4 = [
      "10.9.2.1"
    ];
    ipv6 = [
      "2001:5a8:608c:4a00::21/64"
    ];
    environment = "dev";
    roles = [
      "server"
      "workstation"
      "dev"
      "dev-gui"
      "media"
    ];
    extra_modules =
      with config.flake.aspects;
      [
        disk-single.nixos
        cpu-intel.nixos
        gpu-intel.nixos
        podman.nixos
        wireless.nixos
      ]
      ++ [
        inputs.nixos-hardware.nixosModules.microsoft-surface-pro-intel
      ];
    facts = ./facter.json;
    nixosConfiguration =
      {
        pkgs,
        ...
      }:

      {
        # boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_cachyos-gcc; # TODO: https://github.com/chaotic-cx/nyx/issues/1178

        boot.kernelModules = [
          "hid-microsoft"
          "battery"
          "ac"
        ];
        boot.initrd.kernelModules = [
          # Surface Aggregator Module (SAM): buttons, sensors, keyboard
          "surface_aggregator"
          "surface_aggregator_registry"
          "surface_aggregator_hub"
          "surface_hid_core"
          "surface_hid"

          # Intel Low Power Subsystem (keyboard, I2C, etc.)
          "intel_lpss"
          "intel_lpss_pci"
          "8250_dw"
        ];

        hardware.microsoft-surface.kernelVersion = "stable";

        environment.systemPackages = with pkgs; [
          #for camera
          libcamera

          # for Battery
          tlp
          upower
          acpi
        ];

        services.udev.packages = [ pkgs.iptsd ];
        systemd.packages = [ pkgs.iptsd ];

        hardware.networking.interfaces = [ "wlp1s0" ];

        system.stateVersion = "25.05";
      };
  };
}
