{ inputs, ... }:
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
      "network-manager"
      "microvm"
      "microvm-cuda"
      "windows-vfio"
      "gamedev"
      "easyeffects"
      "media-data-share"
      "cad"
      "podman"
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
      # let
      #   custom-monado = pkgs.monado.overrideAttrs (old: {
      #     src = pkgs.fetchFromGitHub {
      #       owner = "ToasterUwU";
      #       repo = "monado";
      #       rev = "8f85280c406ce2e23939c58bc925cf939f36e1e8";
      #       hash = "sha256-ZeSmnAZ2gDiLTdlVAKQeS3cc6fcRBcSjYZf/M6eI8j4=";
      #     };

      #     cmakeFlags = old.cmakeFlags ++ [
      #       (pkgs.lib.cmakeBool "XRT_HAVE_OPENCV" false)
      #     ];
      #   });

      #   custom-xrizer = pkgs.xrizer.overrideAttrs rec {
      #     src = pkgs.fetchFromGitHub {
      #       owner = "RinLovesYou";
      #       repo = "xrizer";
      #       rev = "f491eddd0d9839d85dbb773f61bd1096d5b004ef";
      #       hash = "sha256-12M7rkTMbIwNY56Jc36nC08owVSPOr1eBu0xpJxikdw=";
      #     };

      #     cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
      #       inherit src;
      #       hash = "sha256-87JcULH1tAA487VwKVBmXhYTXCdMoYM3gOQTkM53ehE=";
      #     };

      #     patches = [ ];

      #     doCheck = false;
      #   };

      #   monado-start-desktop = pkgs.makeDesktopItem {
      #     exec = "monado-start";
      #     icon = "steamvr";
      #     name = "Start Monado";
      #     desktopName = "Start Monado";
      #     terminal = true;
      #   };

      #   monado-start = pkgs.stdenv.mkDerivation {
      #     pname = "monado-start";
      #     version = "3.1.0";

      #     src = pkgs.writeShellApplication {
      #       name = "monado-start";

      #       runtimeInputs =
      #         with pkgs;
      #         [
      #           wlx-overlay-s
      #           wayvr-dashboard
      #           # index_camera_passthrough
      #           lighthouse-steamvr
      #           kdePackages.kde-cli-tools
      #         ]
      #         ++ [
      #           lovr-playspace
      #         ];

      #       text = ''
      #         GROUP_PID_FILE="/tmp/monado-group-pid-$$"

      #         function off() {
      #           echo "Stopping Monado and other stuff..."

      #           if [ -f "$GROUP_PID_FILE" ]; then
      #             PGID=$(cat "$GROUP_PID_FILE")
      #             echo "Killing process group $PGID..."
      #             kill -- -"$PGID" 2>/dev/null
      #             rm -f "$GROUP_PID_FILE"
      #           fi

      #           systemctl --user --no-block stop monado.service
      #           lighthouse -vv --state off &
      #           wait

      #           exit 0
      #         }

      #         function on() {
      #           echo "Starting Monado and other stuff..."

      #           lighthouse -vv --state on &
      #           systemctl --user restart monado.service

      #           setsid sh -c '
      #             # lovr-playspace &
      #             wlx-overlay-s --replace &
      #             # index_camera_passthrough &
      #             # kde-inhibit --power --screenSaver sleep infinity &
      #             wait
      #           ' &
      #           PGID=$!
      #           echo "$PGID" > "$GROUP_PID_FILE"
      #         }

      #         trap off EXIT INT TERM
      #         echo "Press ENTER to turn everything OFF."

      #         on
      #         read -r
      #         off
      #       '';
      #     };

      #     installPhase = ''
      #       mkdir -p $out/bin
      #       cp $src/bin/monado-start $out/bin/
      #       chmod +x $out/bin/monado-start

      #       cp -r ${monado-start-desktop}/* $out/
      #     '';

      #     meta = {
      #       description = "Start script for monado and all other things i use with it.";
      #     };
      #   };
      # in
      {
        imports = [
          inputs.nixpkgs-xr.nixosModules.nixpkgs-xr
        ];

        nixpkgs.xr.enable = true;

        # Kisnt KN85 workaround...
        boot.kernelModules = [ "hid_apple" ];
        boot.extraModprobeConfig = "options hid_apple fnmode=2 swap_opt_cmd=0";

        hardware.disk.zfs-disk-single.device_id = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNU0X704630A";

        hardware.networking.interfaces = [ "enp8s0" ];
        # For Network Manager TODO: RENAME

        hardware.networking.unmanagedInterfaces = [
          "enp8s0"
          "br0"
        ];

        boot.kernelPackages = pkgs.linuxPackages_cachyos.cachyOverride { mArch = "ZEN4"; };

        # Bigscreen Beyond Kernel patches from LVRA Discord Thread
        boot.kernelPatches = [
          {
            name = "0001-drm-edid-parse-DRM-VESA-dsc-bpp-target";
            patch = ./patches/0001-drm-edid-parse-DRM-VESA-dsc-bpp-target.patch;
          }
          {
            name = "0002-drm-amd-use-fixed-dsc-bits-per-pixel-from-edid";
            patch = ./patches/0002-drm-amd-use-fixed-dsc-bits-per-pixel-from-edid.patch;
          }
          {
            # see https://wiki.nixos.org/wiki/VR#Applying_as_a_NixOS_kernel_patch
            name = "amdgpu-ignore-ctx-privileges";
            patch = pkgs.fetchpatch {
              name = "cap_sys_nice_begone.patch";
              url = "https://github.com/Frogging-Family/community-patches/raw/master/linux61-tkg/cap_sys_nice_begone.mypatch";
              hash = "sha256-Y3a0+x2xvHsfLax/uwycdJf3xLxvVfkfDVqjkxNaYEo=";
            };
          }
        ];

        # Udev rules for Bigscreen devices
        services.udev.extraRules = ''
          # Bigscreen Beyond
          KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="0101", MODE="0660", TAG+="uaccess"
          # Bigscreen Bigeye
          KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="0202", MODE="0660", TAG+="uaccess", GROUP="users"
          SUBSYSTEM=="usb", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="0202", MODE="0660", TAG+="uaccess", GROUP="users"
          # Bigscreen Beyond Audio Strap
          KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="0105", MODE="0660", TAG+="uaccess"
          # Bigscreen Beyond Firmware Mode?
          KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="4004", MODE="0660", TAG+="uaccess"
        '';

        chaotic.hdr = {
          enable = true;
          specialisation.enable = false;
        };

        environment.systemPackages =
          with pkgs;
          [
            libsurvive
            xrgears
            openvr
            libusb1
            bs-manager
            eepyxr
            wlx-overlay-s
            lovr-playspace
            resolute
            # monado-start
            pkgs.lighthouse-steamvr
          ]
          ++ [ inputs.buttplug-lite.packages.x86_64-linux.default ];

        programs.steam.extraCompatPackages = [ pkgs.proton-ge-rtsp-bin ];

        # services.monado = {
        #   enable = true;
        #   # forceDefaultRuntime = true;
        #   # defaultRuntime = true;
        #   highPriority = true;
        #   package = custom-monado;
        # };

        # systemd.user.services.monado = {
        #   serviceConfig.LimitNOFILE = 8192;
        #   environment = {
        #     #     # STEAMVR_PATH = "${config.hm.xdg.dataHome}/Steam/steamapps/common/SteamVR";
        #     #     # XR_RUNTIME_JSON = "${config.hm.xdg.configHome}/openxr/1/active_runtime.json";
        #     AMD_VULKAN_ICD = "RADV";
        #     VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json";

        #     STEAMVR_LH_ENABLE = "1";
        #     XRT_COMPOSITOR_COMPUTE = "1";
        #     XRT_COMPOSITOR_FORCE_WAYLAND_DIRECT = "1";
        #     # XRT_DEBUG_GUI = "1";
        #     # XRT_CURATED_GUI = "1";
        #     XRT_COMPOSITOR_SCALE_PERCENTAGE = "100";
        #     # XRT_COMPOSITOR_PRINT_MODES = "1";
        #     XRT_COMPOSITOR_LOG = "debug";
        #     XRT_COMPOSITOR_DESIRED_MODE = "1";
        #     XRT_COMPOSITOR_USE_PRESENT_WAIT = "1";
        #     # XRT_COMPOSITOR_FORCE_GPU_INDEX = "3";
        #     # XRT_COMPOSITOR_FORCE_CLIENT_GPU_INDEX = "4";
        #     #     # XRT_COMPOSITOR_DESIRED_MODE=0 is the 75hz mode
        #     #     # XRT_COMPOSITOR_DESIRED_MODE=1 is the 90hz mode
        #   };

        # };

        home-manager = {
          users.sini = {
            xdg.configFile.".config/openxr/1/active_runtime.json".text = ''
              {
                "file_format_version": "1.0.0",
                "runtime": {
                  "VALVE_runtime_is_steamvr": true,
                  "library_path": "/home/sini/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/vrclient.so",
                  "name": "SteamVR"
                }
              }
            '';
            xdg.configFile.".config/openvr/openvrpaths.vrpath".text = ''
              {
                "config" :
                [
                  "/home/sini/.local/share/Steam/config"
                ],
                "external_drivers" : null,
                "jsonid" : "vrpathreg",
                "log" :
                [
                  "/home/sini/.local/share//Steam/logs"
                ],
                "runtime" :
                [
                  "/home/sini/.local/share/Steam/steamapps/common/SteamVR"
                ],
                "version" : 1
              }
            '';
            # home.file.".local/share/monado/hand-tracking-models".source = pkgs.fetchgit {
            #   url = "https://gitlab.freedesktop.org/monado/utilities/hand-tracking-models";
            #   sha256 = "x/X4HyyHdQUxn3CdMbWj5cfLvV7UyQe1D01H93UCk+M=";
            #   fetchLFS = true;
            # };

            # xdg.configFile."openxr/1/active_runtime.json".source =
            #   "${custom-monado}/share/openxr/1/openxr_monado.json";

            # xdg.configFile."openvr/openvrpaths.vrpath".text = ''
            #   {
            #     "config" :
            #     [
            #       "~/.local/share/Steam/config"
            #     ],
            #     "external_drivers" : null,
            #     "jsonid" : "vrpathreg",
            #     "log" :
            #     [
            #       "~/.local/share/Steam/logs"
            #     ],
            #     "runtime" :
            #     [
            #       "${custom-xrizer}/lib/xrizer",
            #       "${pkgs.opencomposite}/lib/opencomposite"
            #       "~/.local/share/Steam/steamapps/common/SteamVR"

            #     ],
            #     "version" : 1
            #   }
            # '';

            # xdg.configFile."openvr/openvrpaths.vrpath".text = ''
            #   {
            #     "config" :
            #     [
            #       "~/.local/share/Steam/config"
            #     ],
            #     "external_drivers" : null,
            #     "jsonid" : "vrpathreg",
            #     "log" :
            #     [
            #       "~/.local/share/Steam/logs"
            #     ],
            #     "runtime" :
            #     [
            #       "${custom-xrizer}/lib/xrizer",
            #       "~/.local/share/Steam/steamapps/common/SteamVR"
            #     ],
            #     "version" : 1
            #   }
            # '';

            # xdg.configFile."wlxoverlay/conf.d/zz-saved-config.json5".text = ''
            #   {
            #     "watch_pos": [
            #       -0.059999954,
            #       -0.022,
            #       0.1760001
            #     ],
            #     "watch_rot": [
            #       -0.6760993,
            #       0.11002616,
            #       0.707073,
            #       -0.17551248
            #     ],
            #     "watch_hand": "Left",
            #     "watch_view_angle_min": 0.5,
            #     "watch_view_angle_max": 0.7,
            #     "notifications_enabled": true,
            #     "notifications_sound_enabled": true,
            #     "realign_on_showhide": true,
            #     "allow_sliding": true,
            #     "space_drag_multiplier": 1.0,
            #     "block_game_input": true
            #   }
            # '';

            # xdg.configFile."wlxoverlay/watch.yaml".text = ''
            #   width: 0.115

            #   size: [400, 200]

            #   elements:
            #     # batteries
            #     - type: BatteryList
            #       rect: [0, 5, 400, 30]
            #       corner_radius: 4
            #       font_size: 16
            #       fg_color: "#8bd5ca"
            #       fg_color_low: "#B06060"
            #       fg_color_charging: "#6080A0"
            #       num_devices: 9
            #       layout: Horizontal
            #       low_threshold: 33

            #     # background panel
            #     - type: Panel
            #       rect: [0, 30, 400, 130]
            #       corner_radius: 20
            #       bg_color: "#24273a"

            #     # local clock
            #     - type: Label
            #       rect: [13, 85, 200, 50]
            #       corner_radius: 4
            #       font_size: 46 # Use 32 for 12-hour time
            #       fg_color: "#cad3f5"
            #       source: Clock
            #       format: "%H:%M" # 23:59
            #       #format: "%I:%M %p" # 11:59 PM

            #     # local date
            #     - type: Label
            #       rect: [15, 125, 200, 20]
            #       corner_radius: 4
            #       font_size: 14
            #       fg_color: "#cad3f5"
            #       source: Clock
            #       format: "%x" # local date representation

            #     # local day-of-week
            #     - type: Label
            #       rect: [15, 145, 200, 50]
            #       corner_radius: 4
            #       font_size: 14
            #       fg_color: "#cad3f5"
            #       source: Clock
            #       format: "%A" # Tuesday
            #       #format: "%a" # Tue

            #     # Open eepyxr
            #     - type: Button
            #       rect: [187, 42, 73, 32]
            #       corner_radius: 4
            #       font_size: 14
            #       fg_color: "#cad3f5"
            #       bg_color: "#5b6078"
            #       text: "eep"
            #       click_down:
            #         - type: Exec
            #           command: ["eepyxr"]
            #     # Close eepyxr
            #     - type: Button
            #       rect: [264, 42, 73, 32]
            #       corner_radius: 4
            #       font_size: 14
            #       fg_color: "#cad3f5"
            #       bg_color: "#5b6078"
            #       text: "awak"
            #       click_down:
            #         - type: Exec
            #           command: ["pkill", "eepyxr"]

            #     # Open lovr-playspace
            #     - type: Button
            #       rect: [187, 79, 73, 32]
            #       corner_radius: 4
            #       font_size: 14
            #       fg_color: "#cad3f5"
            #       bg_color: "#5b6078"
            #       text: "caged"
            #       click_down:
            #         - type: Exec
            #           command: ["lovr-playspace"]
            #     # Close lovr-playspace
            #     - type: Button
            #       rect: [264, 79, 73, 32]
            #       corner_radius: 4
            #       font_size: 14
            #       fg_color: "#cad3f5"
            #       bg_color: "#5b6078"
            #       text: "free"
            #       click_down:
            #         - type: Exec
            #           command: ["pkill", "lovr"]

            #     # Previous track
            #     - type: Button
            #       rect: [187, 116, 73, 32]
            #       corner_radius: 4
            #       font_size: 14
            #       fg_color: "#cad3f5"
            #       bg_color: "#5b6078"
            #       text: "⏮️"
            #       click_down:
            #         - type: Exec
            #           command: ["playerctl", "previous"]
            #     # Next track
            #     - type: Button
            #       rect: [264, 116, 73, 32]
            #       corner_radius: 4
            #       font_size: 14
            #       fg_color: "#cad3f5"
            #       bg_color: "#5b6078"
            #       text: "⏭️"
            #       click_down:
            #         - type: Exec
            #           command: ["playerctl", "next"]

            #     ## Volume buttons
            #     # Vol+
            #     - type: Button
            #       rect: [355, 42, 30, 32]
            #       corner_radius: 4
            #       font_size: 13
            #       fg_color: "#cad3f5"
            #       bg_color: "#5b6078"
            #       text: "🔊"
            #       click_down:
            #         - type: Exec
            #           command: ["pactl", "set-sink-volume", "@DEFAULT_SINK@", "+5%"]
            #     # Play/Pause
            #     - type: Button
            #       rect: [355, 79, 30, 32]
            #       corner_radius: 4
            #       font_size: 13
            #       fg_color: "#cad3f5"
            #       bg_color: "#5b6078"
            #       text: "⏯"
            #       click_down:
            #         - type: Exec
            #           command: ["playerctl", "play-pause"]
            #     # Vol-
            #     - type: Button
            #       rect: [355, 116, 30, 32]
            #       corner_radius: 4
            #       font_size: 13
            #       fg_color: "#cad3f5"
            #       bg_color: "#5b6078"
            #       text: "🔉"
            #       click_down:
            #         - type: Exec
            #           command: ["pactl", "set-sink-volume", "@DEFAULT_SINK@", "-5%"]

            #     ## Bottom button row
            #     # Config button
            #     - type: Button
            #       rect: [2, 162, 26, 36]
            #       corner_radius: 4
            #       font_size: 15
            #       bg_color: "#c6a0f6"
            #       fg_color: "#24273a"
            #       text: "C"
            #       click_up: # destroy if exists, otherwise create
            #         - type: Window
            #           target: settings
            #           action: ShowUi # only triggers if not exists
            #         - type: Window
            #           target: settings
            #           action: Destroy # only triggers if exists since before current frame

            #     # Dashboard toggle button
            #     - type: Button
            #       rect: [32, 162, 48, 36]
            #       corner_radius: 4
            #       font_size: 15
            #       bg_color: "#2288FF"
            #       fg_color: "#24273a"
            #       text: "Dash"
            #       click_up:
            #         - type: WayVR
            #           action: ToggleDashboard

            #     # Keyboard button
            #     - type: Button
            #       rect: [84, 162, 48, 36]
            #       corner_radius: 4
            #       font_size: 15
            #       fg_color: "#24273a"
            #       bg_color: "#a6da95"
            #       text: Kbd
            #       click_up:
            #         - type: Overlay
            #           target: "kbd"
            #           action: ToggleVisible
            #       long_click_up:
            #         - type: Overlay
            #           target: "kbd"
            #           action: Reset
            #       right_up:
            #         - type: Overlay
            #           target: "kbd"
            #           action: ToggleImmovable
            #       middle_up:
            #         - type: Overlay
            #           target: "kbd"
            #           action: ToggleInteraction
            #       scroll_up:
            #         - type: Overlay
            #           target: "kbd"
            #           action:
            #             Opacity: { delta: 0.025 }
            #       scroll_down:
            #         - type: Overlay
            #           target: "kbd"
            #           action:
            #             Opacity: { delta: -0.025 }

            #     # bottom row, of keyboard + overlays
            #     - type: OverlayList
            #       rect: [134, 160, 266, 40]
            #       corner_radius: 4
            #       font_size: 15
            #       fg_color: "#cad3f5"
            #       bg_color: "#1e2030"
            #       layout: Horizontal
            #       click_up: ToggleVisible
            #       long_click_up: Reset
            #       right_up: ToggleImmovable
            #       middle_up: ToggleInteraction
            #       scroll_up:
            #         Opacity: { delta: 0.025 }
            #       scroll_down:
            #         Opacity: { delta: -0.025 }
            # '';

            # xdg.configFile."wlxoverlay/wayvr.yaml".text = ''
            #   dashboard:
            #     exec: "wayvr-dashboard"
            #     args: ""
            #     env: ["GDK_BACKEND=wayland"]
            # '';

            # xdg.configFile."wlxoverlay/conf.d/skybox.yaml".text = ''
            #   skybox_texture: ${./assets/battlefront-2.dds}
            # '';

            # xdg.configFile."index_camera_passthrough/index_camera_passthrough.toml".text = ''
            #   backend="openxr"
            #   open_delay = "0s"

            #   [overlay.position]
            #   mode = "Hmd"
            #   distance = 0.7

            #   [display_mode]
            #   mode = "Stereo"
            #   projection_mode = "FromEye"
            # '';

            # xdg.dataFile."LOVR/lovr-playspace/fade_start.txt".text = ''
            #   0.1
            # '';
            # xdg.dataFile."LOVR/lovr-playspace/fade_stop.txt".text = ''
            #   0.3
            # '';
          };
        };

        # Enable fan sensors...
        # boot.kernelModules = [
        #   "it87" # Fan options
        # ];
        # boot.extraModprobeConfig = ''
        #   options it87 ignore_resource_conflict=1 force_id=0x8628
        # '';

        # environment.systemPackages = with pkgs; [
        #   lm_sensors
        # ];

        # Host-specific home-manager configuration
        home-manager.sharedModules = [
          {
            wayland.windowManager.hyprland.settings.monitor = [
              "DP-2, 2560x1440@165.00, 0x0, 1, vrr, 1, transform, 1"
              "DP-1, 3840x2160@119.88, 2560x0, 1, vrr, 1, bitdepth, 10"
              "DP-3, 2560x2880@59.98, 6400x0, 1.25, vrr, 0, bitdepth, 10"
            ];
          }
        ];

        impermanence = {
          #   enable = true;
          wipeRootOnBoot = true;
          wipeHomeOnBoot = false;
        };

        system.stateVersion = "25.05";
      };
  };
}
