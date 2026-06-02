{ den, ... }:
{
  den.aspects.roles.gaming = {
    colmena = [ "gaming" ];
    includes = with den.aspects; [
      hardware.gamepad
      core.system.nix-ld
      apps.gaming.steam
      apps.gaming.sunshine
      apps.gaming.mangohud
      apps.gaming.emulation
    ];
  };
}
