{ den, ... }:
{
  den.aspects.roles.headscale = {
    colmena-tags = [ "headscale" ];
    includes = [ den.aspects.services.headscale ];
  };
}
