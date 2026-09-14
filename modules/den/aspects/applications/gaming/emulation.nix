{ inputs, ... }:
{
  den.aspects.applications.gaming.emulation = {
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
          # NOT wine-ge: GloriousEggroll archived wine-ge-custom at GE-Proton8-26
          # (2024-02-04) and points users at umu-launcher, which has its own
          # aspect. wine-tkg is nix-gaming's own default wine, is WoW64, and
          # tracks Wine master -- ntsync above needs a Wine far newer than the
          # Wine 8 base wine-ge was stuck on.
          package = inputs'.nix-gaming.packages.wine-tkg;
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
          # pkgs.azahar # TODO: Safe to re-enable
          pkgs.dolphin-emu
          pkgs.cemu
          pkgs.ryubing
          # pkgs.local.citron # TODO: Safe to re-enable
          # pkgs.local.eden
          # pkgs.moonlight-qt
        ];
      };
  };
}
