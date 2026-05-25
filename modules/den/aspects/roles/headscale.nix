{ den, ... }:
{
  den.aspects.roles.headscale = {
    colmena = [ "headscale" ];
    includes = [ den.aspects.services.headscale ];
  };
}
