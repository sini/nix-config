{
  flake.features.emulation = {
    nixos =
      { lib, pkgs, ... }:
      {
        # wine support
        environment.systemPackages = [ pkgs.wine-ge ];

        environment.sessionVariables.WINE_BIN = lib.getExe pkgs.wine-ge;

        boot.binfmt.registrations."DOSWin" = {
          wrapInterpreterInShell = false;
          interpreter = lib.getExe pkgs.wine-ge;
          recognitionType = "magic";
          offset = 0;
          magicOrExtension = "MZ";
        };

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
          ryubing
          pkgs.local.citron
          pkgs.local.eden

          # Remote play
          moonlight-qt # Client
        ];

      };
  };
}
