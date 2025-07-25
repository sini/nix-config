{
  flake.modules.nixos.steam =
    {
      lib,
      inputs,
      pkgs,
      config,
      ...
    }:
    let
      patchDesktop =
        pkg: appName: from: to:
        lib.hiPrio (
          pkgs.runCommand "patched-desktop-${appName}" { } ''
            ${pkgs.coreutils}/bin/mkdir -p $out/share/applications
            ${pkgs.gnused}/bin/sed 's#${from}#${to}#g' < ${pkg}/share/applications/${appName}.desktop > $out/share/applications/${appName}.desktop
          ''
        );

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
      };
    in
    {
      imports = [ inputs.nix-gaming.nixosModules.platformOptimizations ];

      nix.settings = {
        substituters = [ "https://nix-gaming.cachix.org" ];
        trusted-public-keys = [ "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4=" ];
      };

      environment.systemPackages = with pkgs; [
        lutris
        wine
        winetricks
        wineWowPackages.waylandFull
        inputs.nix-gaming.packages.${pkgs.system}.star-citizen
        (lib.mkIf config.hardware.nvidia.prime.offload.enable (
          patchDesktop steamPkg "steam" "^Exec=" "Exec=nvidia-offload "
        ))
      ];

      hardware = {
        steam-hardware.enable = true;
        xone.enable = true; # support for the xbox controller USB dongle
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
        };

        gamescope = {
          enable = true;
          package = pkgs.gamescope_git;
          capSysNice = true;
          #capSysNice = false; # 'true' breaks gamescope for Steam https://github.com/NixOS/nixpkgs/issues/292620#issuecomment-2143529075
          args = [
            #   # "-W ${toString hostConfig.primaryDisplay.width}"
            #   # "-H ${toString hostConfig.primaryDisplay.height}"
            #   # "-r ${toString hostConfig.primaryDisplay.refreshRate}"
            #   # "-O ${hostConfig.primaryDisplay.name}"
            #   "-f"
            "--adaptive-sync"
            "--mangoapp"
            "--rt"
            "--expose-wayland"
          ];
        };
        gamemode = {
          enable = true;
          enableRenice = true;
        };
      };

      # Smooth-criminal bleeding-edge Mesa3D
      # WARNING: It will break NVIDIA's libgbm, don't use with NVIDIA Optimus setups.
      chaotic.mesa-git = lib.mkIf (!config.hardware.nvidia.prime.offload.enable) {
        enable = true;
        fallbackSpecialisation = false;
      };
    };

}
