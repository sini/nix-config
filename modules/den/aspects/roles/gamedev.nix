{ den, ... }:
{
  den.aspects.roles.gamedev = {
    colmena = [ "gamedev" ];
    includes = with den.aspects.roles.creative; [
      game-engines
      pixel-art
      graphics
      daw
      chiptune
    ];
  };
}
