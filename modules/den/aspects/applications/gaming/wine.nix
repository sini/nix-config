# wine: Windows binaries outside Steam's Proton, and the prefix they share (~/.wine).
# Included by the steam and emulation aspects, which both run it.
{ inputs, ... }:
{
  den.aspects.applications.gaming.wine = {
    nixos =
      { pkgs, inputs', ... }:
      {
        imports = [ inputs.nix-gaming.nixosModules.wine ];

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

        environment.systemPackages = [
          pkgs.wine
          pkgs.winetricks
          pkgs.wineWow64Packages.waylandFull
        ];
      };

    # The default prefix: installed programs and their settings.
    persistHome.directories = [ ".wine" ];
  };
}
