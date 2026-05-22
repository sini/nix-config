{ den, inputs, ... }:
{
  den.aspects.hardware.vr-amd = {
    nixos =
      { pkgs, ... }:
      {
        imports = [
          inputs.nixpkgs-xr.nixosModules.nixpkgs-xr
        ];

        nixpkgs.xr.enable = true;

        hardware.graphics.extraPackages = [ pkgs.monado-vulkan-layers ];

        boot.kernelPatches = [
          {
            name = "amdgpu-ignore-ctx-privileges";
            patch = pkgs.fetchpatch {
              name = "cap_sys_nice_begone.patch";
              url = "https://github.com/Frogging-Family/community-patches/raw/master/linux61-tkg/cap_sys_nice_begone.mypatch";
              hash = "sha256-Y3a0+x2xvHsfLax/uwycdJf3xLxvVfkfDVqjkxNaYEo=";
            };
          }
        ];

        services.udev = {
          packages = [ pkgs.openvr ];

          extraRules = ''
            # Bigscreen Beyond
            KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="0101", MODE="0666", TAG+="uaccess"
            # Bigscreen Bigeye
            KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="0202", MODE="0666", TAG+="uaccess", GROUP="video"
            SUBSYSTEM=="usb", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="0202", MODE="0660", TAG+="uaccess", GROUP="video"
            # Bigscreen Beyond Audio Strap
            KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="0105", MODE="0666", TAG+="uaccess"
            # Bigscreen Beyond Firmware Mode
            KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="4004", MODE="0666", TAG+="uaccess"
          '';
        };

        programs.steam.extraCompatPackages = [ pkgs.proton-ge-rtsp-bin ];

        environment.systemPackages = [
          pkgs.monado-vulkan-layers
          pkgs.libsurvive
          pkgs.xrgears
          pkgs.openvr
          pkgs.libusb1
          pkgs.bs-manager
          pkgs.wayvr
          pkgs.resolute
          pkgs.lighthouse-steamvr
          pkgs.custom-monado
          pkgs.custom-xrizer
          pkgs.sidequest
        ];

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
            U_PACING_COMP_PRESENT_TO_DISPLAY_OFFSET = "5";
            U_PACING_APP_USE_MIN_FRAME_PERIOD = "1";
            XRT_COMPOSITOR_FORCE_GPU_INDEX = "0";
            IPC_EXIT_WHEN_IDLE = "on";
            IPC_EXIT_WHEN_IDLE_DELAY_MS = "300000";
          };
        };
      };

    homeManager =
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

        xdg.configFile = {
          "openxr/1/active_runtime.json".source = "${pkgs.custom-monado}/share/openxr/1/openxr_monado.json";
          "openvr/openvrpaths.vrpath".text = ''
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
        };

        home = {
          packages = [ pkgs.flatpak ];

          sessionVariables = {
            XDG_DATA_DIRS = "$XDG_DATA_DIRS:/usr/share:/var/lib/flatpak/exports/share:$HOME/.local/share/flatpak/exports/share";
          };
        };

        services.flatpak = {
          enable = true;
          packages = [
            "io.github.wivrn.wivrn"
            "com.github.tchx84.Flatseal"
            "org.freedesktop.Bustle"
            "com.valvesoftware.Steam"
          ];

          update.auto = {
            enable = true;
            onCalendar = "weekly";
          };

          overrides = {
            "com.valvesoftware.Steam".Context = {
              filesystems = [
                "xdg-run/wivrn:ro"
                "xdg-data/flatpak/app/io.github.wivrn.wivrn:ro"
                "xdg-config/openxr:ro"
                "xdg-config/openvr:ro"
              ];
            };
          };
        };

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
