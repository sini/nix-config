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
    den.aspects.core.users.home-manager-collector

    (den.lib.policy.mkPolicy "home-manager-modules-propagation" (
      { ... }:
      let
        inherit (den.lib.policy) pipe;
      in
      [ (pipe.from "homeManagerModules" [ ]) ]
    ))

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
