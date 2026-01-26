{
  flake.features.emulation = {
    nixos =
      { inputs, pkgs, ... }:
      {
        imports = [
          inputs.nix-gaming.nixosModules.wine
        ];

        programs.wine = {
          enable = true;
          package = inputs.nix-gaming.packages.${pkgs.stdenv.hostPlatform.system}.wine-ge;
          binfmt = true;
          ntsync = true;
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
          igir # Rom organization
          prismlauncher # Minecraft launcher
          lutris # General games

          # Emulators
          sameboy # GB/GBC
          mgba # GBA
          melonDS # DS
          azahar # 3DS
          dolphin-emu # Wii/GameCube
          cemu # Wii U

          ryubing
          pkgs.local.citron
          pkgs.local.eden

          # Remote play
          moonlight-qt # Client
        ];

      };
  };
}
