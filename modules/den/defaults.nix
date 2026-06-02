{ den, lib, ... }:
{
  # Reserve 'settings' so aspects can declare typed settings without pipeline dispatch
  den.reservedKeys = [ "settings" ];

  # Default host includes — aggregator aspects for quirk collection
  den.schema.host.includes = [
    den.aspects.core.network.firewall-collector
    den.aspects.core.secrets.collector
  ];

  # Default user includes — per-user data emission + entity-named aspect auto-include
  den.schema.user.includes = [
    den.aspects.core.users.resolved-user-emitter

    # Include den.aspects.<hostname>.<username> if it exists
    (den.lib.policy.mkPolicy "user-aspect-auto-include" (
      { host, user, ... }:
      lib.optional (den.aspects ? ${host.name} && den.aspects.${host.name} ? ${user.name}) (
        den.lib.policy.include den.aspects.${host.name}.${user.name}
      )
    ))
  ];

  # Wire den batteries that every host/user should have
  # home-manager and os-class are support modules (not battery aspects) —
  # they auto-load via den's flakeModule and wire their own schema/policies.
  den.default.includes = [
    den.batteries.define-user
    den.batteries.hostname
    den.batteries.primary-user
    den.batteries.inputs'
    den.batteries.self'
  ];

}
