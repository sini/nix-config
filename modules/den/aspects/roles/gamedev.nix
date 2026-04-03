# Gamedev role: game development tools including engines, art, and audio.
{ den, ... }:
{
  den.aspects.gamedev = {
    includes = [
      den.aspects.game-engines
      den.aspects.pixel-art
      den.aspects.graphics
      den.aspects.daw
      den.aspects.chiptune
    ];
  };
}
