{ den, ... }:
{
  den.aspects.roles.gamedev = {
    colmena-tags = [ "gamedev" ];
    includes = with den.aspects.roles.creative; [
      game-engines
      pixel-art
      graphics
      daw
      chiptune
    ];
  };
}
