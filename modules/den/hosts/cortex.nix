{ den, ... }:
{
  den.hosts.x86_64-linux.cortex = {
    channel = "nixpkgs-master";
    environment = "dev";
    system-owner = "sini";
    system-access-groups = [ "workstation-access" ];

    networking.interfaces.enp8s0 = {
      ipv4 = [ "10.9.2.1/16" ];
      ipv6 = [ "fd64:0:1::5/64" ];
    };

    settings = {
      disk.zfs-disk-single.device_id = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNU0X704630A";
      core.system.linux-kernel.optimization = "zen4";
      core.impermanence = {
        wipeRootOnBoot = true;
        wipeHomeOnBoot = false;
      };
    };
  };

  den.aspects.cortex = {
    includes = with den.aspects; [
      roles.default
      roles.workstation
      roles.gaming
      roles.dev
      roles.dev-gui
      roles.media
      roles.inference
      roles.messaging
      roles.nix-builder

      hardware.cpu.amd
      hardware.gpu.amd
      hardware.gpu.nvidia-vfio
      hardware.performance
      hardware.vr-amd

      desktop.hyprland
      desktop.uwsm

      disk.zfs-disk-single
      core.network.boot

      virtualization.microvm
      virtualization.microvm-cuda
      virtualization.windows-vfio
      virtualization.podman

      services.storage.media-data-share

      apps.media.easyeffects
    ];

    nixos = {
      boot = {
        kernelParams = [
          "amd_3d_vcache.x3d_mode=cache"
        ];

        extraModprobeConfig = ''
          options snd_usb_audio vid=0x1235 pid=0x8210 device_setup=1 quirk_flags=0x1
        '';
      };

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
                }
              ];
              actions = {
                update-props = {
                  "priority.driver" = "3000";
                  "priority.session" = "3000";
                };
              };
            }
          ];
        };
      };

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
              cm_sdr_eotf = 0;
              non_shader_cm = 2;
            };

            general = {
              allow_tearing = true;
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
                bitdepth = 10;
              }
              {
                output = "DP-2";
                mode = "2560x1440@165.00";
                position = "-1440x0";
                scale = 1;
                vrr = true;
                transform = 1;
              }
              {
                output = "HDMI-A-1";
                mode = "2560x2880@60.00";
                position = "3840x0";
                scale = 1.33;
                vrr = false;
                bitdepth = 10;
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
            "easyeffects/autoload/output/bluez_output.38_8F_30_F0_D1_9D.1.json".text = builtins.toJSON {
              device = "bluez_output.38_8F_30_F0_D1_9D.1";
              device-description = "Created by Home Manager";
              device-profile = "headset-output";
              preset-name = "GalaxyBuds";
            };
          };
        }
      ];
    };

    sini = {
      includes = with den.aspects; [
        apps.wayland.waybar
        apps.wayland.swaync
        apps.wayland.hypridle
        apps.wayland.hyprland-split-monitors
        apps.media.spotify-player
      ];
    };

    shuo = {
      includes = with den.aspects; [
        apps.browsers.firefox
        apps.gaming.steam
        apps.media.spicetify
      ];
    };
  };
}
