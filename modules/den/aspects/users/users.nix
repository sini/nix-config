{ den, ... }:
{
  den.aspects.users = den.lib.perHost {
    # Simplified user framework - full ACL-driven user provisioning
    # deferred to environment/ACL context migration
    nixos = {
      users.mutableUsers = false;
    };
  };
}
