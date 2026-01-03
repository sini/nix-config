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
      #"gamedev"
      "easyeffects"
      "media-data-share"
      #"cad"
      "podman"
      "vr-amd"

      "hyprland"
      "zen-browser"

      "sddm"
      "kde"
    ];

    exclude-features = [
      "gdm" # these are included with workstation
      "gnome"
      "xdg-portal"
    ];

    users = {
      sini = {
        features = [
          "spotify-player"
          # TODO: properly feature flag these
          "waybar"
          "swaync"
          "hypridle"
          "hyprland-split-monitors"
        ];
      };
      shuo = {
        features = [
          "firefox"
          "steam"
          "spicetify"
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
        # TODO: switch to this fork once it has working ZFS
        boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest-lto;

        boot.kernelParams = [
          "amd_3d_vcache.x3d_mode=cache" # AMD V-Cache https://wiki.cachyos.org/configuration/general_system_tweaks/#amd-3d-v-cache-optimizer
        ];

        hardware.disk.zfs-disk-single.device_id = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNU0X704630A";

        hardware.networking.interfaces = [ "enp8s0" ];

        # hardware.display.edid = {
        #   enable = true;
        #   packages = [
        #     (pkgs.runCommand "samsung-odyssey-ark-g1-edid-firmware" { } ''
        #       mkdir -p $out/lib/firmware/edid
        #       cp ${./firmware/samsung-odyssey-ark-g1.bin} $out/lib/firmware/edid/samsung-odyssey-ark-g1.bin
        #     '')
        #   ];
        # };

        # hardware.display.outputs."DP-1" = {
        #   mode = "e";
        #   edid = "samsung-odyssey-ark-g1.bin";
        # };

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
                    "node.name" = "alsa_output.usb-Topping_D10-00.pro-output-0";
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
            wayland.windowManager.hyprland.settings = {

              debug = {
                full_cm_proto = true;
              };

              misc = {
                vfr = true;
                vrr = 3;
                disable_xdg_env_checks = true;
              };

              render = {
                direct_scanout = 1;
                cm_enabled = true;
                send_content_type = true;
                cm_fs_passthrough = 1;
                cm_auto_hdr = 2;
                expand_undersized_textures = false;
                cm_sdr_eotf = 0; # 1?
                non_shader_cm = 2;
              };

              general = {
                allow_tearing = true;
              };

              experimental = {
                xx_color_management_v4 = true;
              };

              quirks = {
                prefer_hdr = 2;
              };

              monitorv2 = [
                {
                  output = "DP-1";
                  mode = "3840x2160@120.00";
                  position = "0x0";
                  scale = 1;
                  vrr = 0; # We get really bad brightness flickering. :(

                  bitdepth = 10;
                  cm = "hdredid";

                  supports_wide_color = true;
                  supports_hdr = true;
                  # sdrbrightness = 1.05;
                  sdrbrightness = 1.00;

                  sdrsaturation = 0.75;

                  sdr_min_luminance = "0.005";
                  sdr_max_luminance = "200";

                  min_luminance = 0;
                  max_luminance = 1200;
                  max_avg_luminance = 600;
                }
                {
                  output = "DP-2";
                  mode = "2560x1440@165.00";
                  position = "-1440x0";
                  scale = 1;
                  vrr = true;
                  transform = 1;
                }
                # LG DualUp 28MQ780-B
                {
                  output = "HDMI-A-1";
                  mode = "2560x2880@60.00";
                  position = "3840x0";
                  scale = 1.33;
                  vrr = false;

                  bitdepth = 10;
                  cm = "hdredid";

                  supports_wide_color = true;
                  supports_hdr = true;

                  sdrbrightness = 1.00;

                  sdrsaturation = 1.00;

                  sdr_min_luminance = "0.005";
                  sdr_max_luminance = "200";

                  min_luminance = 0;
                  max_luminance = 300;
                  max_avg_luminance = 300;
                }
              ];
            };
            xdg.configFile = {
              "easyeffects/autoload/output/alsa_output.usb-Topping_D10-00.pro-output-0.json".text =
                builtins.toJSON
                  {
                    device = "alsa_output.usb-Topping_D10-00.pro-output-0";
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
