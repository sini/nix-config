{ den, ... }:
{
  den.aspects.roles.headscale = {
    includes = [ den.aspects.services.networking.headscale ];
  };
}
