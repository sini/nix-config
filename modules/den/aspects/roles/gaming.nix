{ den, ... }:
{
  den.aspects.roles.gaming = {
    includes = with den.aspects; [
      hardware.gamepad
      applications.gaming.nix-ld
      applications.gaming.steam
      applications.gaming.sunshine
      applications.gaming.mangohud
      applications.gaming.emulation
    ];
  };
}
