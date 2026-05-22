{ den, ... }:
{
  # Default host includes — aggregator aspects for quirk collection
  den.schema.host.includes = [
    den.aspects.core.firewall-collector
    den.aspects.core.secrets-collector
    den.aspects.core.persist-collector
  ];

  # Default user includes — home persistence aggregator
  den.schema.user.includes = [
    den.aspects.core.persist-home-collector
  ];

  # Wire den batteries that every host/user should have
  # home-manager and os-class are support modules (not battery aspects) —
  # they auto-load via den's flakeModule and wire their own schema/policies.
  den.default.includes = [
    den.batteries.define-user
    den.batteries.hostname
    den.batteries.primary-user
  ];
}
