{ den, ... }:
{
  den.aspects.roles.bgp-hub = {
    colmena-tags = [ "bgp-hub" ];
    includes = [ den.aspects.services.bgp.hub ];
  };
}
