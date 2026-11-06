{ den, ... }:
{
  den.aspects.applications.gaming.emulation = {
    includes = [ den.aspects.applications.gaming.wine ];

    nixos =
      { pkgs, ... }:
      {
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
          # pkgs.lutris # TODO: lutris 0.5.22 pulls gtk2, which nixpkgs marks broken ahead of its removal; re-enable once lutris drops it, or use heroic / faugus-launcher
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

    # Saves, keys and per-emulator config.
    persistHome.directories = [
      ".config/Cemu"
      ".local/share/Cemu"
      ".config/eden"
      ".local/share/eden"
      ".config/citron"
      ".local/share/citron"
      ".local/share/dolphin-emu"
      ".local/share/PrismLauncher"
    ];
  };
}
