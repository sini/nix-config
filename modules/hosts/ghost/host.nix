{ config, ... }:
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
      "laptop"
      "workstation"
      "dev"
      "dev-gui"
      "media"
    ];
    extra_modules = with config.flake.modules.nixos; [
      disk-single
      cpu-intel
      gpu-intel
      podman
    ];
    #  ++ [
    #   inputs.nixos-hardware.nixosModules.microsoft-surface-pro-intel
    # ];
    facts = ./facter.json;
    nixosConfiguration =
      {
        pkgs,
        lib,
        ...
      }:
      let
        linux-surface = builtins.fetchGit {
          url = "https://github.com/linux-surface/linux-surface.git";
          ref = "master";
          rev = "94217c2dc8818afd2296c3776223fc1c093f78fb";
        };

        patchSrc = linux-surface + /patches/6.16;
      in
      {

        # Define the kernel patches. The following URLs proved highly useful in knowing what config options are needed:
        # https://github.com/StollD/fedora-linux-surface/blob/master/config.surface
        # https://github.com/jakeday/linux-surface/issues/496
        boot.kernelPatches = [
          {
            name = "microsoft-surface-patches-linux-6.16";
            patch = null;
            structuredExtraConfig = with lib.kernel; {
              STAGING_MEDIA = yes;
              ##
              ## Surface Aggregator Module
              ##
              CONFIG_SURFACE_AGGREGATOR = module;
              # CONFIG_SURFACE_AGGREGATOR_ERROR_INJECTION is not set
              CONFIG_SURFACE_AGGREGATOR_BUS = yes;
              CONFIG_SURFACE_AGGREGATOR_CDEV = module;
              CONFIG_SURFACE_AGGREGATOR_HUB = module;
              CONFIG_SURFACE_AGGREGATOR_REGISTRY = module;
              CONFIG_SURFACE_AGGREGATOR_TABLET_SWITCH = module;

              CONFIG_SURFACE_ACPI_NOTIFY = module;
              CONFIG_SURFACE_DTX = module;
              CONFIG_SURFACE_PLATFORM_PROFILE = module;

              CONFIG_SURFACE_HID = module;
              CONFIG_SURFACE_KBD = module;

              CONFIG_BATTERY_SURFACE = module;
              CONFIG_CHARGER_SURFACE = module;

              CONFIG_SENSORS_SURFACE_TEMP = module;
              CONFIG_SENSORS_SURFACE_FAN = module;

              CONFIG_RTC_DRV_SURFACE = module;

              ##
              ## Surface Hotplug
              ##
              CONFIG_SURFACE_HOTPLUG = module;

              ##
              ## IPTS and ITHC touchscreen
              ##
              ## This only enables the user interface for IPTS/ITHC data.
              ## For the touchscreen to work, you need to install iptsd.
              ##
              CONFIG_HID_IPTS = module;
              CONFIG_HID_ITHC = module;

              ##
              ## Cameras: IPU3
              ##
              CONFIG_VIDEO_DW9719 = module;
              CONFIG_VIDEO_IPU3_IMGU = module;
              CONFIG_VIDEO_IPU3_CIO2 = module;
              CONFIG_IPU_BRIDGE = module;
              CONFIG_INTEL_SKL_INT3472 = module;
              CONFIG_REGULATOR_TPS68470 = module;
              CONFIG_COMMON_CLK_TPS68470 = module;
              CONFIG_LEDS_TPS68470 = module;

              ##
              ## Cameras: Sensor drivers
              ##
              CONFIG_VIDEO_OV5693 = module;
              CONFIG_VIDEO_OV7251 = module;
              CONFIG_VIDEO_OV8865 = module;

              ##
              ## Surface 3: atomisp causes problems (see issue #1095). Disable it for now.
              ##
              # CONFIG_INTEL_ATOMISP is not set

              ##
              ## ALS Sensor for Surface Book 3, Surface Laptop 3, Surface Pro 7
              ##
              CONFIG_APDS9960 = module;

              ##
              ## Build-in UFS support (required for some Surface Go devices)
              ##
              CONFIG_SCSI_UFSHCD = module;
              CONFIG_SCSI_UFSHCD_PCI = module;

              ##
              ## Other Drivers
              ##
              CONFIG_INPUT_SOC_BUTTON_ARRAY = module;
              CONFIG_SURFACE_3_POWER_OPREGION = module;
              CONFIG_SURFACE_PRO3_BUTTON = module;
              CONFIG_SURFACE_GPE = module;
              CONFIG_SURFACE_BOOK1_DGPU_SWITCH = module;
            };
          }
          {
            name = "ms-surface/0001-secureboot";
            patch = patchSrc + "/0001-secureboot.patch";
          }
          {
            name = "ms-surface/0002-surface3";
            patch = patchSrc + "/0002-surface3.patch";
          }
          {
            name = "ms-surface/0003-mwifiex";
            patch = patchSrc + "/0003-mwifiex.patch";
          }
          {
            name = "ms-surface/0004-ath10k";
            patch = patchSrc + "/0004-ath10k.patch";
          }
          # {
          #   name = "ms-surface/0005-ipts";
          #   patch = patchSrc + "/0005-ipts.patch";
          # }
          # {
          #   name = "ms-surface/0006-ithc";
          #   patch = patchSrc + "/0006-ithc.patch";
          # }
          {
            name = "ms-surface/0007-surface-sam";
            patch = patchSrc + "/0007-surface-sam.patch";
          }
          {
            name = "ms-surface/0008-surface-sam-over-hid";
            patch = patchSrc + "/0008-surface-sam-over-hid.patch";
          }
          {
            name = "ms-surface/0009-surface-button";
            patch = patchSrc + "/0009-surface-button.patch";
          }
          # {
          #   name = "ms-surface/0010-surface-typecover";
          #   patch = patchSrc + "/0010-surface-typecover.patch";
          # }
          {
            name = "ms-surface/0011-surface-shutdown";
            patch = patchSrc + "/0011-surface-shutdown.patch";
          }
          {
            name = "ms-surface/0012-surface-gpe";
            patch = patchSrc + "/0012-surface-gpe.patch";
          }
          # {
          #   name = "ms-surface/0013-cameras";
          #   patch = patchSrc + "/0013-cameras.patch";
          # }
          {
            name = "ms-surface/0014-amd-gpio";
            patch = patchSrc + "/0014-amd-gpio.patch";
          }
          {
            name = "ms-surface/0015-rtc";
            patch = patchSrc + "/0015-rtc.patch";
          }
        ];

        boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_cachyos-gcc; # TODO: https://github.com/chaotic-cx/nyx/issues/1178

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

        # hardware.microsoft-surface.kernelVersion = "stable";

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
