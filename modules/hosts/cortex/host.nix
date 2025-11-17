{
  flake.hosts.cortex = {
    ipv4 = [ "10.9.2.1" ];
    ipv6 = [ "fd64:0:1::5/64" ];
    environment = "dev";
    roles = [
      "workstation"
      "gaming"
      "dev"
      "dev-gui"
      "media"
      "inference"
    ];
    features = [
      "cpu-amd"
      "gpu-amd"
      "network-boot"
      #"gpu-nvidia"
      #"gpu-nvidia-prime"
      "gpu-nvidia-vfio"
      "zfs-disk-single"
      "performance"
      # "network-manager"
      "microvm"
      "microvm-cuda"
      "windows-vfio"
      "gamedev"
      "easyeffects"
      "media-data-share"
      "cad"
      "podman"
      "vr-amd"
    ];
    users = {
      "sini" = {
        "features" = [
          "spotify-player"
        ];
      };
    };
    facts = ./facter.json;
    nixosConfiguration =
      {
        pkgs,
        ...
      }:
      {
        boot.kernelPackages = pkgs.linuxPackages_cachyos.cachyOverride { mArch = "ZEN4"; };

        hardware.disk.zfs-disk-single.device_id = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNU0X704630A";

        hardware.networking.interfaces = [ "enp8s0" ];

        # For Network Manager TODO: RENAME
        hardware.networking.unmanagedInterfaces = [
          "enp8s0"
          "br0"
        ];

        # Quirks for Focusrite
        # https://another.maple4ever.net/archives/2994/
        boot.extraModprobeConfig = ''
          options snd_usb_audio vid=0x1235 pid=0x8210 device_setup=1 quirk_flags=0x1
        '';

        # Set audio rules
        services.pipewire.wireplumber.extraConfig = {
          "10-disable-camera.conf" = {
            "wireplumber.profiles".main."monitor.libcamera" = "disabled";
          };

          "60-dac-priority" = {
            "monitor.alsa.rules" = [
              {
                matches = [
                  {
                    "node.name" = "alsa_input.usb-Focusrite_Scarlett_2i2_USB_Y80HQQ415BC300-00.HiFi__Mic1__source";
                  }
                  {
                    "node.name" = "alsa_output.usb-Topping_D10-00.HiFi__Headphones__sink";
                    # "node.name" = "alsa_output.usb-Focusrite_Scarlett_2i2_USB_Y80HQQ415BC300-00.HiFi__Line1__sink";
                  }
                ];
                actions = {
                  update-props = {
                    # normal input priority is sequential starting at 2000
                    "priority.driver" = "3000";
                    "priority.session" = "3000";
                  };
                };
              }
            ];
          };
        };

        # Host-specific home-manager configuration
        home-manager.sharedModules = [
          {
            wayland.windowManager.hyprland.settings.monitor = [
              "DP-2, 2560x1440@165.00, 0x0, 1, vrr, 1, transform, 1"
              "DP-1, 3840x2160@119.88, 2560x0, 1, vrr, 1, bitdepth, 10"
              "DP-3, 2560x2880@59.98, 6400x0, 1.25, vrr, 0, bitdepth, 10"
            ];
            xdg.configFile = {
              "easyeffects/autoload/output/alsa_output.usb-Topping_D10-00.HiFi__Headphones__sink.json".text =
                builtins.toJSON
                  {
                    device = "alsa_output.usb-Topping_D10-00.HiFi__Headphones__sink";
                    device-description = "Created by Home Manager";
                    device-profile = "[Out] Headphones";
                    preset-name = "HD650-Harmon";
                  };
              "easyeffects/autoload/output/bluez_output.38_8F_30_F0_D1_9D.1.json".text = # DeviceID
                builtins.toJSON {
                  device = "bluez_output.38_8F_30_F0_D1_9D.1";
                  device-description = "Created by Home Manager";
                  device-profile = "headset-output";
                  preset-name = "GalaxyBuds";
                };
            };
          }
        ];

        impermanence = {
          wipeRootOnBoot = true;
          wipeHomeOnBoot = false;
        };

        system.stateVersion = "25.05";
      };
  };
}
