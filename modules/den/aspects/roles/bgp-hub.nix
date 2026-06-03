{ den, ... }:
{
  den.aspects.roles.bgp-hub = {
    includes = [ den.aspects.services.bgp.hub ];
  };
}
