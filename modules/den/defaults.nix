{
  den,
  lib,
  withSystem,
  config,
  inputs,
  ...
}:
let

  mergeInputs = inputs'': lib.mapAttrs (name: input: input // (inputs''.${name} or { })) inputs;

  mkAspectInputs =
    class: system:
    withSystem system (
      { inputs', ... }:
      {
        ${class}._module.args.inputs' = mergeInputs inputs';
      }
    );

  osAspectInputs =
    { host }:
    withSystem host.system (
      { inputs', ... }:
      {
        name = "inputs'/os";
        __scopeHandlers.inputs' = _: {
          resume = mergeInputs inputs' // {
            collisionPolicy = "den-wins";
          };
          state = { };
        };
      }
      // lib.optionalAttrs (host ? class) (mkAspectInputs host.class host.system)
    );

  userAspectInputs =
    {
      user,
      host,
    }:
    withSystem host.system (
      { inputs', ... }:
      {
        name = "inputs'/user";
        includes = map (c: mkAspectInputs c host.system) user.classes;
        __scopeHandlers.inputs' = _: {
          resume = mergeInputs inputs' // {
            collisionPolicy = "den-wins";
          };
          state = { };
        };
      }
    );

  hmAspectInputs =
    { home }:
    withSystem home.system (
      { inputs', ... }:
      {
        name = "inputs'/home";
        __scopeHandlers.inputs' = _: {
          resume = mergeInputs inputs' // {
            collisionPolicy = "den-wins";
          };
          state = { };
        };
      }
      // lib.optionalAttrs (home ? class) (mkAspectInputs home.class home.system)
    );

  mkAspectSelf =
    class: system:
    withSystem system (
      { self', ... }:
      {
        ${class}._module.args.self' = self';
      }
    );

  osAspectSelf =
    { host }:
    withSystem host.system (
      { self', ... }:
      {
        name = "self'/os";
        __scopeHandlers.self' = _: {
          resume = self';
          state = { };
        };
      }
      // lib.optionalAttrs (host ? class) (mkAspectSelf host.class host.system)
    );

  userAspectSelf =
    {
      user,
      host,
    }:
    withSystem host.system (
      { self', ... }:
      {
        name = "self'/user";
        includes = map (c: mkAspectSelf c host.system) user.classes;
        __scopeHandlers.self' = _: {
          resume = self';
          state = { };
        };
      }
    );

  hmAspectSelf =
    { home }:
    withSystem home.system (
      { self', ... }:
      {
        name = "self'/home";
        __scopeHandlers.self' = _: {
          resume = self';
          state = { };
        };
      }
      // lib.optionalAttrs (home ? class) (mkAspectSelf home.class home.system)
    );
in
{
  # Reserve 'settings' so aspects can declare typed settings without pipeline dispatch
  den.reservedKeys = [ "settings" ];

  den.batteries.inputs' = lib.mkForce {
    name = "inputs'";
    includes = [
      osAspectInputs
      userAspectInputs
      hmAspectInputs
    ];
  };

  den.batteries.self' = lib.mkForce {
    name = "self'";
    includes = [
      osAspectSelf
      userAspectSelf
      hmAspectSelf
    ];
  };

  # Default host includes — aggregator aspects for quirk collection
  den.schema.host.includes = [
    den.aspects.core.network.firewall-collector
    den.aspects.core.secrets.collector
  ];

  # Default user includes — per-user data emission + entity-named aspect auto-include
  den.schema.user.includes = [
    den.aspects.core.users.resolved-user-emitter

    # Include den.aspects.<hostname>.<username> if it exists
    #
    # Written as a literal policy record rather than `mkPolicy`, which takes only a name and
    # a body and so has no field to declare a codomain on. The include is value-conditional
    # on the aspect registry holding an entry under this host and user, and a sentinel
    # context names neither — so the body takes the false branch, emits nothing, and the
    # `edge` an include really produces would abort against the recovered empty head.
    {
      __isPolicy = true;
      name = "user-aspect-auto-include";
      emits = [ "edge" ];
      fn =
        { host, user, ... }:
        lib.optional (den.aspects ? ${host.name} && den.aspects.${host.name} ? ${user.name}) (
          den.lib.policy.include den.aspects.${host.name}.${user.name}
        );
    }

    # primary-user grants wheel (+ networkmanager; darwin primaryUser; wsl
    # defaultUser). It must apply ONLY to the host's declared system-owner, not
    # to every login user — otherwise login on a workstation implies sudo.
    # Non-owners still get networkmanager via the acl (workstation-access);
    # wheel stays admin-only via den.groups.wheel.members.
    #
    # A literal policy record for the same reason as the one above: the ownership test is
    # value-conditional, it is false at a sentinel that supplies no system-owner, and the
    # include's `edge` has to be stated rather than fired for.
    {
      __isPolicy = true;
      name = "primary-user-for-owner";
      emits = [ "edge" ];
      fn =
        { host, user, ... }:
        lib.optional (user.name == (host.system-owner or null)) (
          den.lib.policy.include den.batteries.primary-user
        );
    }
  ];

  # Wire den batteries that every host/user should have
  # home-manager and os-class are support modules (not battery aspects) —
  # they auto-load via den's flakeModule and wire their own schema/policies.
  den.default.includes = [
    den.batteries.define-user
    den.batteries.hostname
    # primary-user is NOT a blanket default: it grants wheel, so it is applied
    # per system-owner via the "primary-user-for-owner" policy above.
    den.batteries.inputs'
    den.batteries.self'
  ];
}
