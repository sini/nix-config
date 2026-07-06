{ inputs, ... }:
{
  den.aspects.apps.gaming.emulation = {
    nixos =
      {
        pkgs,
        inputs',
        ...
      }:
      {
        imports = [
          inputs.nix-gaming.nixosModules.wine
        ];

        programs.wine = {
          enable = true;
          package = inputs'.nix-gaming.packages.wine-ge;
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
          #pkgs.local.citron # TODO: Safe to re-enable
          #pkgs.local.eden
          pkgs.moonlight-qt
        ];
      };
  };
}
