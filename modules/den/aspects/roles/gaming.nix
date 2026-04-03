# Gaming role: gamepad, Steam, streaming, and emulation.
{ den, ... }:
{
  den.aspects.gaming = {
    includes = [
      den.aspects.gamepad
      den.aspects.nix-ld
      den.aspects.steam
      den.aspects.sunshine
      den.aspects.mangohud
      den.aspects.emulation
    ];
  };
}
