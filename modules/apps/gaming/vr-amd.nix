{
  flake.features.vr-amd = {
    requires = [ "steam" ];
    nixos =
      { pkgs, inputs, ... }:
      {
        imports = [
          inputs.nixpkgs-xr.nixosModules.nixpkgs-xr
        ];

        nixpkgs.xr.enable = true;

        # Monado vulkan layers
        hardware.graphics.extraPackages = [ pkgs.monado-vulkan-layers ];

        # Bigscreen Beyond Kernel patches from LVRA Discord Thread
        boot.kernelPatches = [
          {
            name = "0001-drm-edid-rename-VESA-block-parsing-functions-to-more";
            patch = ./patches/0001-drm-edid-rename-VESA-block-parsing-functions-to-more.patch;
          }
          {
            name = "0002-drm-edid-prepare-for-VESA-vendor-specific-data-block";
            patch = ./patches/0002-drm-edid-prepare-for-VESA-vendor-specific-data-block.patch;
          }
          {
            name = "0003-drm-edid-MSO-should-only-be-used-for-non-eDP-display";
            patch = ./patches/0003-drm-edid-MSO-should-only-be-used-for-non-eDP-display.patch;
          }
          {
            name = "0004-drm-edid-parse-DSC-DPP-passthru-support-flag-for-mod";
            patch = ./patches/0004-drm-edid-parse-DSC-DPP-passthru-support-flag-for-mod.patch;
          }
          {
            name = "0005-drm-edid-for-consistency-use-mask-everywhere-for-blo";
            patch = ./patches/0005-drm-edid-for-consistency-use-mask-everywhere-for-blo.patch;
          }
          {
            name = "0006-drm-edid-parse-DRM-VESA-dsc-bpp-target";
            patch = ./patches/0006-drm-edid-parse-DRM-VESA-dsc-bpp-target.patch;
          }
          {
            name = "0007-drm-amd-use-fixed-dsc-bits-per-pixel-from-edid";
            patch = ./patches/0007-drm-amd-use-fixed-dsc-bits-per-pixel-from-edid.patch;
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

        # Udev rules for VR devices
        services.udev.packages = with pkgs; [
          openvr
        ];

        # Udev rules for Bigscreen devices
        services.udev.extraRules = ''
          # Bigscreen Beyond
          KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="0101", MODE="0666", TAG+="uaccess"
          # Bigscreen Bigeye
          KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="0202", MODE="0666", TAG+="uaccess", GROUP="video"
          SUBSYSTEM=="usb", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="0202", MODE="0660", TAG+="uaccess", GROUP="video"
          # Bigscreen Beyond Audio Strap
          KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="0105", MODE="0666", TAG+="uaccess"
          # Bigscreen Beyond Firmware Mode?
          KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="4004", MODE="0666", TAG+="uaccess"
        '';

        programs.steam.extraCompatPackages = [ pkgs.proton-ge-rtsp-bin ];

        environment.systemPackages = with pkgs; [
          monado-vulkan-layers
          libsurvive
          xrgears
          openvr
          libusb1
          bs-manager
          eepyxr
          wlx-overlay-s
          # lovr-playspace
          resolute
          lighthouse-steamvr
          custom-monado
          custom-xrizer
          sidequest
        ];

        # ++ [ inputs.buttplug-lite.packages.x86_64-linux.default ];

        # https://monado.freedesktop.org/valve-index-setup.html
        # clear .config/libsurvive
        # put headset on floor in center of playspace, no trackers or controllers connected, and power it on
        # run 2x for 30 seconds: survive-cli --steamvr-calibration
        # now monado will be able to start
        services.monado = {
          enable = true;
          defaultRuntime = false;
          highPriority = true;
          package = pkgs.custom-monado;
        };

        systemd.user.services.monado = {
          serviceConfig.LimitNOFILE = 8192;
          environment = {
            AMD_VULKAN_ICD = "RADV";
            STEAMVR_LH_ENABLE = "1";
            XRT_COMPOSITOR_COMPUTE = "1";
            WMR_HANDTRACKING = "1";
            XRT_DEBUG_VK = "1";
            XRT_COMPOSITOR_FORCE_WAYLAND_DIRECT = "1";
            XRT_COMPOSITOR_SCALE_PERCENTAGE = "150";
            OXR_VIEWPORT_SCALE_PERCENTAGE = "125";
            XRT_COMPOSITOR_DESIRED_MODE = "0";
            # XRT_COMPOSITOR_DESIRED_MODE=0 is the 75hz mode
            # XRT_COMPOSITOR_DESIRED_MODE=1 is the 90hz mode
            U_PACING_COMP_PRESENT_TO_DISPLAY_OFFSET = "5";
            U_PACING_APP_USE_MIN_FRAME_PERIOD = "1";
            XRT_COMPOSITOR_FORCE_GPU_INDEX = "0";
            # WAYLAND_DISPLAY = "wayland-1";

            IPC_EXIT_WHEN_IDLE = "on"; # kill on idle! :)
            IPC_EXIT_WHEN_IDLE_DELAY_MS = "300000"; # 5 minutes
          };
        };
        # services.wivrn = {
        #   enable = true;

        #   package = pkgs.wivrn;

        #   autoStart = true;
        #   openFirewall = true;
        #   highPriority = true;
        #   defaultRuntime = true;
        #   steam.importOXRRuntimes = true;

        #   config = {
        #     enable = true;

        #     json = {
        #       bitrate = 135000000;
        #       # application = pkgs.wlx-overlay-s;
        #     };
        #   };
        # };
        # services.desktopManager.gnome.sessionPath = [ pkgs.sidequest ];
      };
    home =
      {
        config,
        inputs,
        pkgs,
        ...
      }:
      {

        imports = [
          inputs.nix-flatpak.homeManagerModules.nix-flatpak
        ];

        xdg.configFile."openxr/1/active_runtime.json".source =
          "${pkgs.custom-monado}/share/openxr/1/openxr_monado.json";
        xdg.configFile."openvr/openvrpaths.vrpath".text = ''
          {
            "config" :
            [
              "${config.xdg.dataHome}/Steam/config"
            ],
            "external_drivers" :
            [
              "${pkgs.custom-monado}/share/steamvr-monado"
            ],
            "jsonid" : "vrpathreg",
            "log" :
            [
              "${config.xdg.dataHome}/Steam/logs"
            ],
            "runtime" :
            [
              "${pkgs.custom-xrizer}/lib/xrizer"
            ],
            "version" : 1
          }
        '';
        # "external_drivers" :
        # [
        #   "${config.xdg.dataHome}/Steam/steamapps/common/Bigscreen Beyond Driver"
        # ],

        #        "${pkgs.custom-xrizer}/lib/xrizer",
        #       "/home/sini/.local/share/Steam/steamapps/common/SteamVR"
        # xdg.configFile.".config/openxr/1/active_runtime.json".text = ''
        #   {
        #     "file_format_version": "1.0.0",
        #     "runtime": {
        #       "VALVE_runtime_is_steamvr": true,
        #       "library_path": "/home/sini/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/vrclient.so",
        #       "name": "SteamVR"
        #     }
        #   }
        # '';
        # xdg.configFile.".config/openvr/openvrpaths.vrpath".text = ''
        #   {
        #     "config" :
        #     [
        #       "/home/sini/.local/share/Steam/config"
        #     ],
        #     [
        #       "${config.xdg.dataHome}/Steam/steamapps/common/Bigscreen Beyond Driver"
        #     ],
        #     "jsonid" : "vrpathreg",
        #     "log" :
        #     [
        #       "/home/sini/.local/share//Steam/logs"
        #     ],
        #     "runtime" :
        #     [
        #       "/home/sini/.local/share/Steam/steamapps/common/SteamVR"
        #     ],
        #     "version" : 1
        #   }
        # '';

        #   activation.link-steamvr-openxr-runtime = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        #     RUNTIME_PATH="$HOME/.config/openxr/1/active_runtime.json"

        #     run mkdir -p $VERBOSE_ARG \
        #       "$HOME/.config/openxr/1/";

        #     if [ -L "$RUNTIME_PATH" ]; then
        #       run rm $VERBOSE_ARG \
        #         "$RUNTIME_PATH";
        #     fi

        #     run ln -s $VERBOSE_ARG \
        #       "$HOME/.local/share/Steam/steamapps/common/SteamVR/steamxr_linux64.json" "$RUNTIME_PATH";
        #   '';
        # };
        home.packages = with pkgs; [
          flatpak
        ];

        home.sessionVariables = {
          XDG_DATA_DIRS = "$XDG_DATA_DIRS:/usr/share:/var/lib/flatpak/exports/share:$HOME/.local/share/flatpak/exports/share"; # lets flatpak work
        };

        services.flatpak.enable = true;
        services.flatpak.packages = [
          "io.github.wivrn.wivrn" # SteamVR app streaming from linux
          "com.github.tchx84.Flatseal"
          "org.freedesktop.Bustle"
          "com.valvesoftware.Steam"
        ];

        services.flatpak.update.auto = {
          enable = true;
          onCalendar = "weekly"; # Default value
        };

        services.flatpak.overrides = {
          "com.valvesoftware.Steam".Context = {
            filesystems = [
              ## For Wivrn to work
              "xdg-run/wivrn:ro"
              "xdg-data/flatpak/app/io.github.wivrn.wivrn:ro"
              "xdg-config/openxr:ro"
              "xdg-config/openvr:ro"
            ];
          };
        };

        # system.activationScripts.steamflatpak-openxr = ''
        #   mkdir -p ~/.var/app/com.valvesoftware.Steam/.config/openxr
        #   ln -sf ~/.config/openxr/1 ~/.var/app/com.valvesoftware.Steam/.config/openxr/1
        # '';

        xdg.mimeApps = {
          defaultApplications = {
            "x-scheme-handler/steam" = "steam.desktop";
            "x-scheme-handler/vrmonitor" = "valve-URI-vrmonitor.desktop";
            "application/x-vrmonitor" = "valve-vrmonitor.desktop";
          };
          associations.added = {
            "x-scheme-handler/steam" = "steam.desktop";
            "x-scheme-handler/vrmonitor" = "valve-URI-vrmonitor.desktop";
            "application/x-vrmonitor" = "valve-vrmonitor.desktop";
          };
        };

        home.file.".local/share/monado/hand-tracking-models".source = pkgs.fetchgit {
          url = "https://gitlab.freedesktop.org/monado/utilities/hand-tracking-models";
          sha256 = "x/X4HyyHdQUxn3CdMbWj5cfLvV7UyQe1D01H93UCk+M=";
          fetchLFS = true;
        };
      };
  };
}
