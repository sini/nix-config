{ den, ... }:
{
  den.aspects.apps.steam = {
    nixos =
      {
        lib,
        pkgs,
        host,
        ...
      }:
      let
        hasNvidiaPrimeOnLaptop =
          host.hasAspect den.aspects.hardware.gpu-nvidia-prime && host.hasAspect den.aspects.roles.laptop;
      in
      {
        nix.settings = {
          substituters = [ "https://nix-gaming.cachix.org" ];
          trusted-public-keys = [ "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4=" ];
        };

        environment.systemPackages = [
          pkgs.wine
          pkgs.winetricks
          pkgs.wineWow64Packages.waylandFull
        ];

        hardware = {
          steam-hardware.enable = true;
          graphics.enable32Bit = true;
        };

        programs = {
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
                  inherit (pkgs') lib;
                  mkDeps =
                    pkgsSet: with pkgsSet; [
                      qt6.qtwayland
                      xdg-utils
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
                      libxkbcommon
                      freetype
                      fontconfig
                      glib
                      libpng
                      libpulseaudio
                      libvorbis
                      libkrb5
                      keyutils
                      libglvnd
                      libdrm
                      vulkan-tools
                      vulkan-loader
                      vulkan-validation-layers
                      vulkan-extension-layer
                      (lib.getLib stdenv.cc.cc)
                    ];
                in
                mkDeps pkgs';

              extraLibraries =
                p: with p; [
                  atk
                ];
            };

            extraCompatPackages = [
              pkgs.proton-ge-bin
              pkgs.proton-cachyos-x86_64_v4
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
        };
      };

    homeManager =
      { pkgs, lib, ... }:
      {
        home.packages = [
          (pkgs.steam.override {
            extraEnv = {
              MANGOHUD = true;
              OBS_VKCAPTURE = true;
              PROTON_ENABLE_WAYLAND = true;
              PROTON_ENABLE_HDR = true;
              PROTON_USE_NTSYNC = true;
              PROTON_USE_WOW64 = true;
              RADV_TEX_ANISO = 16;
              PULSE_SINK = "Game";
            };
            extraPkgs =
              pkgs': with pkgs'; [
                qt6.qtwayland
                xdg-utils
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
                libxkbcommon
                freetype
                fontconfig
                glib
                libpng
                libpulseaudio
                libvorbis
                libkrb5
                keyutils
                libglvnd
                libdrm
                vulkan-tools
                vulkan-loader
                vulkan-validation-layers
                vulkan-extension-layer
                (lib.getLib stdenv.cc.cc)
              ];
            extraLibraries = p: with p; [ atk ];
          })
        ];
      };

    provides.impermanence = {
      homeManager = {
        home.persistence."/cache".directories = [
          ".local/share/Steam"
        ];
      };
    };
  };
}
