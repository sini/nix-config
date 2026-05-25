{ den, ... }:
{
  # Marker role — identifies hosts as BGP spoke peers for hub auto-discovery
  den.aspects.roles.bgp-spoke = {
    colmena-tags = [ "bgp-spoke" ];
    includes = [ den.aspects.services.bgp.spoke ];
  };
}
