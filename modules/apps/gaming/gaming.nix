{
  flake.features.gaming = {
    nixos =
      { pkgs, ... }:
      {
        services.udev.packages = [
          pkgs.dolphin-emu
          pkgs.game-devices-udev-rules
        ];

        programs.ns-usbloader.enable = true;
      };
    home =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          prismlauncher # Minecraft launcher
          lutris # General games

          # Emulators
          sameboy # GB/GBC
          mgba # GBA
          melonDS # DS
          lime3ds # 3DS
          dolphin-emu # Wii/GameCube
          cemu # Wii U
          torzu_git # Switch

          # Remote play
          moonlight-qt # Client

          # VR tools
          sidequest
        ];

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
  };
}
