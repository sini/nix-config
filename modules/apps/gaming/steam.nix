{
  flake.features.steam = {
    nixos =
      {
        lib,
        pkgs,
        activeFeatures,
        ...
      }:
      let
        # Check if both gpu-nvidia-prime and laptop features are active
        hasNvidiaPrimeOnLaptop =
          lib.elem "gpu-nvidia-prime" activeFeatures && lib.elem "laptop" activeFeatures;
      in
      {
        # nixpkgs.overlays = [ inputs.millennium.overlays.default ];

        nix.settings = {
          substituters = [ "https://nix-gaming.cachix.org" ];
          trusted-public-keys = [ "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4=" ];
        };

        environment.systemPackages = with pkgs; [
          wine
          winetricks
          wineWow64Packages.waylandFull
        ];

        hardware = {
          steam-hardware.enable = true;
          graphics.enable32Bit = true; # 32-bit support for games
        };

        programs = {
          # Some steam applications require AppImage support
          appimage.enable = true;
          appimage.binfmt = true;

          steam = {
            enable = true;
            remotePlay.openFirewall = true;
            dedicatedServer.openFirewall = true;
            localNetworkGameTransfers.openFirewall = true;
            protontricks.enable = true;

            package = pkgs.steam.override {
              extraEnv = {
                MANGOHUD = true;
                OBS_VKCAPTURE = true;
                PROTON_ENABLE_WAYLAND = true;
                PROTON_ENABLE_HDR = true;
                PROTON_USE_NTSYNC = true;
                PROTON_USE_WOW64 = true;
                RADV_TEX_ANISO = 16;
                PULSE_SINK = "Game";
              }
              // lib.optionalAttrs hasNvidiaPrimeOnLaptop {
                NV_PRIME_RENDER_OFFLOAD = "1";
                "__NV_PRIME_RENDER_OFFLOAD_PROVIDER" = "NVIDIA-G0";
                "__GLX_VENDOR_LIBRARY_NAME" = "nvidia";
                "__VK_LAYER_NV_optimus" = "NVIDIA_only";
              };
              extraPkgs =
                pkgs':
                let
                  mkDeps =
                    pkgsSet: with pkgsSet; [
                      qt6.qtwayland
                      xdg-utils

                      # Core X11 libs required by many titles
                      libx11
                      libxext
                      libxrender
                      libxi
                      libxinerama
                      libxcursor
                      libxscrnsaver
                      libsm
                      libice
                      libxcb
                      libxrandr

                      # Common multimedia/system libs
                      libxkbcommon
                      freetype
                      fontconfig
                      glib
                      libpng
                      libpulseaudio
                      libvorbis
                      libkrb5
                      keyutils

                      # GL/Vulkan plumbing for AMD on X11 (host RADV)
                      libglvnd
                      libdrm
                      vulkan-tools
                      vulkan-loader
                      vulkan-validation-layers
                      vulkan-extension-layer

                      # libstdc++ for the runtime
                      (lib.getLib stdenv.cc.cc)
                    ];
                in
                mkDeps pkgs';

              extraLibraries =
                p: with p; [
                  atk
                ];
            };

            extraCompatPackages = with pkgs; [
              proton-ge-bin
              # https://github.com/powerofthe69/proton-cachyos-nix
              proton-cachyos-x86_64_v4
            ];

            gamescopeSession = {
              enable = true;

              env = {
                DXVK_HDR = "1";
              };

              args = [
                "--rt"
                "--hdr-enabled"
                "--hdr-itm-enabled"
                "--hdr-debug-force-output"
                "--xwayland-count 2"
                "-W 3840"
                "-H 2160"
                "-r 120"
              ];
            };
          };

          # gamescope = {
          #   enable = true;
          #   package = pkgs.gamescope_git;
          #   capSysNice = true;
          #   #capSysNice = false; # 'true' breaks gamescope for Steam https://github.com/NixOS/nixpkgs/issues/292620#issuecomment-2143529075
          #   args = [
          #     #   # "-W ${toString hostOptions.primaryDisplay.width}"
          #     #   # "-H ${toString hostOptions.primaryDisplay.height}"
          #     #   # "-r ${toString hostOptions.primaryDisplay.refreshRate}"
          #     #   # "-O ${hostOptions.primaryDisplay.name}"
          #     #   "-f"
          #     "--adaptive-sync"
          #     "--mangoapp"
          #     "--rt"
          #     "--expose-wayland"
          #     "--hdr-enabled"
          #     "--hdr-itm-enabled"
          #     "--hdr-debug-force-output"
          #     "--xwayland-count 2"
          #     "-W 3840"
          #     "-H 2160"
          #     "-r 120"
          #   ];
          # };

          # gamemode = {
          #   enable = true;
          #   enableRenice = true;
          #   settings = {
          #     general = {
          #       softrealtime = "auto";
          #       renice = 15;
          #     };

          #     gpu = lib.mkIf (!hasNvidiaPrimeOnLaptop) {
          #       apply_gpu_optimisations = "accept-responsibility";
          #       gpu_device = 0;
          #       amd_performance_level = "high";
          #     };

          #     custom = {
          #       start = "${lib.getExe pkgs.libnotify} 'GameMode started'";
          #       end = "${lib.getExe pkgs.libnotify} 'GameMode ended'";
          #     };
          #   };

          # };
        };
      };

    home =
      { ... }:
      {
        home.persistence."/cache".directories = [
          ".local/share/Steam"
        ];
      };
  };
}
