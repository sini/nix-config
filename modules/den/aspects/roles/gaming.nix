{ den, ... }:
{
  den.aspects.roles.gaming = {
    includes = with den.aspects; [
      hardware.gamepad
      system.nix-ld
      apps.steam
      apps.sunshine
      apps.mangohud
      apps.emulation
    ];
  };
}
