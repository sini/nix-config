# Host-level schema wiring.
#
# Wires env-users and host-users onto host scope so user resolution
# fires for every host in the fleet.
{ den, ... }:
{
  den.schema.host.includes = [
    den.policies.env-users
    den.policies.host-users
  ];
}
