{ inputs, ... }:
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

        # https://wiki.nixos.org/wiki/VR#Applying_as_a_NixOS_kernel_patch
        #
        # The patch rewrites amdgpu_ctx_priority_permit()'s final `return
        # -EACCES` to `return 0`, so any process on the system can take a
        # high-priority GPU context. Async reprojection needs one.
        #
        # Disabled because our OpenXR path is Monado (active_runtime.json below)
        # reached via xrizer, and services.monado.highPriority already puts a
        # cap_sys_nice+eip wrapper on monado-service, which satisfies the
        # unpatched check. This is NOT a general substitute: Steam runs under
        # bubblewrap in a user namespace that strips capabilities outright, so
        # no security.wrappers entry can help SteamVR's own runtime or the
        # flatpak WiVRn. If SteamVR async reprojection regresses, the cheapest
        # remedy is a manual setcap on Steam's own binary, which lives outside
        # the store and can therefore hold file capabilities:
        #   sudo setcap CAP_SYS_NICE=eip \
        #     ~/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/vrcompositor-launcher
        # https://vronlinux.org/docs/distros/nixos/
        #
        # boot.kernelPatches = [
        #   {
        #     name = "amdgpu-ignore-ctx-privileges";
        #     patch = pkgs.fetchpatch {
        #       name = "cap_sys_nice_begone.patch";
        #       url = "https://github.com/Frogging-Family/community-patches/raw/master/linux61-tkg/cap_sys_nice_begone.mypatch";
        #       hash = "sha256-Y3a0+x2xvHsfLax/uwycdJf3xLxvVfkfDVqjkxNaYEo=";
        #     };
        #   }
        # ];

        # Headset-specific udev rules live in their own aspect, e.g.
        # hardware.bigscreen-beyond.
        services.udev.packages = [ pkgs.openvr ];

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
          pkgs.monado
          pkgs.xrizer
          pkgs.sidequest
        ];

        services.monado = {
          enable = true;
          defaultRuntime = false;
          highPriority = true;
          #package = pkgs.custom-monado;
        };

        # WayVR registers an OpenVR autostart manifest holding its own store
        # path, which goes stale after a GC. `--replace` rewrites it each login.
        # https://wiki.nixos.org/wiki/VR#SteamVR_autostart
        # Correct for our Monado/xrizer path. Under SteamVR as the compositor
        # WayVR must be launched as `steam-run wayvr` instead, because Steam's
        # FHS blocks it -- https://vronlinux.org/docs/distros/nixos/
        systemd.user.services.wayvr = {
          description = "WayVR desktop overlay for OpenXR/OpenVR";
          partOf = [ "graphical-session.target" ];
          after = [ "graphical-session.target" ];
          wantedBy = [ "graphical-session.target" ];
          serviceConfig = {
            ExecStart = "${pkgs.wayvr}/bin/wayvr --replace";
            Restart = "on-failure";
          };
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
            U_PACING_COMP_PRESENT_TO_DISPLAY_OFFSET = "5";
            U_PACING_APP_USE_MIN_FRAME_PERIOD = "1";
            XRT_COMPOSITOR_FORCE_GPU_INDEX = "0";
            IPC_EXIT_WHEN_IDLE = "on";
            IPC_EXIT_WHEN_IDLE_DELAY_MS = "300000";
          };
        };
      };

    homeManagerModules =
      { inputs', ... }:
      [
        inputs'.nix-flatpak.homeManagerModules.nix-flatpak
      ];

    homeManager =
      {
        config,
        pkgs,
        ...
      }:
      {

        xdg.configFile = {
          "openxr/1/active_runtime.json".source = "${pkgs.monado}/share/openxr/1/openxr_monado.json";
          "openvr/openvrpaths.vrpath".text =
            let
              steam = "${config.xdg.dataHome}/Steam";
            in
            builtins.toJSON {
              version = 1;

              jsonid = "vrpathreg";

              external_drivers = [ "${pkgs.monado}/share/steamvr-monado" ];

              config = [ "${steam}/config" ];

              log = [ "${steam}/logs" ];

              runtime = [ "${pkgs.xrizer}/lib/xrizer" ];
            };

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
