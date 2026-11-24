# Fleet user access grants — maps user groups to environments and hosts.
#
# Users in the registry whose groups intersect these grants get resolved
# onto hosts by the fleet-access assignment policy (policies/users.nix).
{
  fleet.user-access = {
    by-environment = {
      prod.groups = [
        "system-access"
        "workstation-access"
      ];
      dev.groups = [
        "system-access"
        "workstation-access"
      ];
    };
  };
}
