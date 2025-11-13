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
          azahar # 3DS
          dolphin-emu # Wii/GameCube
          cemu # Wii U

          # TODO: Torzu lives on TOR now, need tor onion access to download the git repo.
          #torzu_git # Switch
          pkgs.local.citron
          pkgs.local.eden

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
