# Host-level schema wiring.
#
# Wires the fleet-access assignment policy (policies/users.nix) onto every host:
# it puts each host's admitted registry users on host.users before resolution.
{ den, ... }:
{
  den.schema.host.includes = [
    den.policies.fleet-access
  ];
}
