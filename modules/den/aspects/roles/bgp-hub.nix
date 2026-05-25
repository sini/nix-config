{ den, ... }:
{
  den.aspects.roles.bgp-hub = {
    colmena = [ "bgp-hub" ];
    includes = [ den.aspects.services.bgp.hub ];
  };
}
