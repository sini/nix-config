{
  flake.features.vr-amd = {
    requires = [ "steam" ];
    nixos =
      { pkgs, inputs, ... }:
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

        programs.steam.extraCompatPackages = [ pkgs.proton-ge-rtsp-bin ];

        environment.systemPackages = with pkgs; [
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
          # VR tools
          sidequest
        ];

        # ++ [ inputs.buttplug-lite.packages.x86_64-linux.default ];

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

        home.file.".local/share/monado/hand-tracking-models".source = pkgs.fetchgit {
          url = "https://gitlab.freedesktop.org/monado/utilities/hand-tracking-models";
          sha256 = "x/X4HyyHdQUxn3CdMbWj5cfLvV7UyQe1D01H93UCk+M=";
          fetchLFS = true;
        };
      };
  };
}
