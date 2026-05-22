{ den, inputs, ... }:
{
  den.aspects.apps.emulation = {
    nixos =
      {
        pkgs,
        ...
      }:
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

    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.igir
          pkgs.prismlauncher
          pkgs.lutris
          pkgs.sameboy
          pkgs.mgba
          pkgs.melonds
          pkgs.azahar
          pkgs.dolphin-emu
          pkgs.cemu
          pkgs.ryubing
          pkgs.local.citron
          pkgs.local.eden
          pkgs.moonlight-qt
        ];
      };
  };
}
