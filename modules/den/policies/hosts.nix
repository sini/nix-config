# Host-level schema wiring.
#
# Wires env-users onto host scope so user resolution fires for every
# host in the fleet. Access groups (merged env + host grants, gated by
# system-access-groups) are propagated via scope context from fleet policy.
{ den, ... }:
{
  den.schema.host.includes = [
    den.policies.env-users
  ];
}
