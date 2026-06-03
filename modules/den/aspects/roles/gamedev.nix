{ den, ... }:
{
  den.aspects.roles.gamedev = {
    includes = with den.aspects.roles.creative; [
      game-engines
      pixel-art
      graphics
      daw
      chiptune
    ];
  };
}
