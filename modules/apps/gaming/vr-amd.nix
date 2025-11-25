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

        # Udev rules for Bigscreen devices
        services.udev.extraRules = ''
          # Bigscreen Beyond
          KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="0101", MODE="0666", TAG+="uaccess"
          # Bigscreen Bigeye
          KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="0202", MODE="0666", TAG+="uaccess", GROUP="users"
          SUBSYSTEM=="usb", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="0202", MODE="0660", TAG+="uaccess", GROUP="users"
          # Bigscreen Beyond Audio Strap
          KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="0105", MODE="0666", TAG+="uaccess"
          # Bigscreen Beyond Firmware Mode?
          KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="4004", MODE="0666", TAG+="uaccess"
        '';

        programs.steam.extraCompatPackages = [ pkgs.proton-ge-rtsp-bin ];

        environment.systemPackages = with pkgs; [
          # monado-vulkan-layers
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
          custom-monado
          # monado
          custom-xrizer
          # VR tools
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
          defaultRuntime = true;
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
            XRT_COMPOSITOR_SCALE_PERCENTAGE = "200";
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
      { pkgs, ... }:
      {

        xdg.configFile."openxr/1/active_runtime.json".source =
          "${pkgs.custom-monado}/share/openxr/1/openxr_monado.json";
        xdg.configFile."openvr/openvrpaths.vrpath".text = ''
          {
            "config" :
            [
              "/home/sini/.local/share/Steam/config"
            ],
            "external_drivers" : null,
            "jsonid" : "vrpathreg",
            "log" :
            [
              "/home/sini/.local/share/Steam/logs"
            ],
            "runtime" :
            [
              "${pkgs.custom-xrizer}/lib/xrizer"
            ],
            "version" : 1
          }
        '';
        #"${pkgs.custom-xrizer}/lib/xrizer"
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
        #     "external_drivers" : null,
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

        home.file.".local/share/monado/hand-tracking-models".source = pkgs.fetchgit {
          url = "https://gitlab.freedesktop.org/monado/utilities/hand-tracking-models";
          sha256 = "x/X4HyyHdQUxn3CdMbWj5cfLvV7UyQe1D01H93UCk+M=";
          fetchLFS = true;
        };
      };
  };
}
