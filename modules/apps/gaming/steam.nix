{
  flake.features.steam = {
    nixos =
      {
        lib,
        inputs,
        pkgs,
        activeFeatures,
        ...
      }:
      let
        # Check if both gpu-nvidia-prime and laptop features are active
        hasNvidiaPrimeOnLaptop =
          lib.elem "gpu-nvidia-prime" activeFeatures && lib.elem "laptop" activeFeatures;

        patchDesktop =
          pkg: appName: from: to:
          lib.hiPrio (
            pkgs.runCommand "patched-desktop-${appName}" { } ''
              ${pkgs.coreutils}/bin/mkdir -p $out/share/applications
              ${pkgs.gnused}/bin/sed 's#${from}#${to}#g' < ${pkg}/share/applications/${appName}.desktop > $out/share/applications/${appName}.desktop
            ''
          );

        patchedBwrap = pkgs.bubblewrap.overrideAttrs (o: {
          patches = (o.patches or [ ]) ++ [
            ./bwrap.patch
          ];
        });

        steamPkg = pkgs.steam.override {
          extraEnv = {
            MANGOHUD = true;
            OBS_VKCAPTURE = true;
            PROTON_ENABLE_WAYLAND = true;
            PROTON_ENABLE_HDR = true;
            PROTON_USE_NTSYNC = true;
            PROTON_USE_WOW64 = true;
            PULSE_SINK = "Game";
          };
          extraProfile = ''
            unset TZ
          '';
          buildFHSEnv = (
            args:
            (
              (pkgs.buildFHSEnv.override {
                bubblewrap = patchedBwrap;
              })
              (
                args
                // {
                  extraBwrapArgs = (args.extraBwrapArgs or [ ]) ++ [ "--cap-add ALL" ];
                }
              )
            )
          );
        };
      in
      {
        imports = [ inputs.nix-gaming.nixosModules.platformOptimizations ];

        nix.settings = {
          substituters = [ "https://nix-gaming.cachix.org" ];
          trusted-public-keys = [ "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4=" ];
        };

        environment.systemPackages =
          with pkgs;
          [
            wine
            winetricks
            wineWowPackages.waylandFull
          ]
          ++ lib.optional hasNvidiaPrimeOnLaptop (
            patchDesktop steamPkg "steam" "^Exec=" "Exec=nvidia-offload "
          );

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
            platformOptimizations.enable = true;
            remotePlay.openFirewall = true;
            dedicatedServer.openFirewall = true;
            localNetworkGameTransfers.openFirewall = true;
            protontricks.enable = true;
            package = steamPkg;
            extraPackages = [ pkgs.latencyflex-vulkan ];
            extraCompatPackages = with pkgs; [
              luxtorpeda
              # proton-ge-bin
              proton-ge-custom # From chaotic
              steamtinkerlaunch
              proton-cachyos # From chaotic
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

          gamescope = {
            enable = true;
            package = pkgs.gamescope_git;
            capSysNice = true;
            #capSysNice = false; # 'true' breaks gamescope for Steam https://github.com/NixOS/nixpkgs/issues/292620#issuecomment-2143529075
            args = [
              #   # "-W ${toString hostOptions.primaryDisplay.width}"
              #   # "-H ${toString hostOptions.primaryDisplay.height}"
              #   # "-r ${toString hostOptions.primaryDisplay.refreshRate}"
              #   # "-O ${hostOptions.primaryDisplay.name}"
              #   "-f"
              "--adaptive-sync"
              "--mangoapp"
              "--rt"
              "--expose-wayland"
              "--hdr-enabled"
              "--hdr-itm-enabled"
              "--hdr-debug-force-output"
              "--xwayland-count 2"
              "-W 3840"
              "-H 2160"
              "-r 120"
            ];
          };

          gamemode = {
            enable = true;
            enableRenice = true;
            settings = {
              general = {
                softrealtime = "auto";
                renice = 15;
              };

              gpu = lib.mkIf (!hasNvidiaPrimeOnLaptop) {
                apply_gpu_optimisations = "accept-responsibility";
                gpu_device = 0;
                amd_performance_level = "high";
              };

              custom = {
                start = "${lib.getExe pkgs.libnotify} 'GameMode started'";
                end = "${lib.getExe pkgs.libnotify} 'GameMode ended'";
              };
            };

          };
        };

        # Smooth-criminal bleeding-edge Mesa3D
        # WARNING: It will break NVIDIA's libgbm, don't use with NVIDIA Optimus setups.
        chaotic.mesa-git = lib.mkIf (!hasNvidiaPrimeOnLaptop) {
          enable = true;
          fallbackSpecialisation = false;
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
