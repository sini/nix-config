# Fleet topology policies.
#
# Wires the scope tree: flake -> fleet -> environment -> hosts.
# Environment membership derived from den.schema.host.environment.
# Environment entities read from the legacy environments registry.
{
  lib,
  den,
  config,
  ...
}:
let
  inherit (den.lib.policy) resolve;

  inherit (config.den) environments;
in
{
  # flake -> fleet: single fleet entity (fires at flake scope).
  # secretsConfig propagates through scope inheritance to all descendants.
  den.policies.to-fleet =
    { self, ... }:
    [
      (resolve.to "fleet" {
        fleet = {
          name = "fleet";
        };
        inherit (config.den) secretsConfig;
      })
    ];

  # fleet -> environments: fan out per registered environment.
  den.policies.fleet-to-envs =
    { self, ... }:
    lib.mapAttrsToList (
      _: env:
      resolve.to "environment" {
        environment = env;
      }
    ) environments;

  # environment -> hosts: walk den.hosts whose environment matches.
  den.policies.env-to-hosts =
    { environment, ... }:
    let
      inherit (config) fleet;
      envGrant = (fleet.user-access.by-environment.${environment.name} or { groups = [ ]; }).groups;
      envGate = environment.system-access-groups or [ ];
    in
    lib.concatMap (
      system:
      lib.concatMap (
        hostName:
        let
          hostCfg = den.hosts.${system}.${hostName};
          hostGrant = (fleet.user-access.by-host.${hostName} or { groups = [ ]; }).groups;
          hostGate = hostCfg.system-access-groups;
          # Effective gate: union of env + host gates (matching main's mergedAccessGroups)
          effectiveGate = lib.unique (envGate ++ hostGate);
          # Effective grant: union of env + host grants + host gates
          # (host system-access-groups is both a gate and an implicit grant)
          allGrants = lib.unique (envGrant ++ hostGrant ++ hostGate);
          # Users must match both a grant AND a gate group
          accessGroups =
            if effectiveGate == [ ] then
              allGrants
            else
              builtins.filter (g: builtins.elem g effectiveGate) allGrants;
        in
        lib.optionals ((hostCfg.environment or "prod") == environment.name && hostCfg.intoAttr != [ ]) [
          (resolve.to "host" {
            host = hostCfg;
            inherit accessGroups;
          })
          (den.lib.policy.instantiate hostCfg)
        ]
      ) (builtins.attrNames (den.hosts.${system} or { }))
    ) (builtins.attrNames (den.hosts or { }));

  # Schema wiring.
  den.schema.flake.includes = [ den.policies.to-fleet ];
  den.schema.fleet.includes = [ den.policies.fleet-to-envs ];
  den.schema.environment.includes = [ den.policies.env-to-hosts ];

  # Fleet handles host instantiation -- exclude default walking policies.
  den.schema.flake-system.excludes = [
    den.policies.system-to-os-outputs
    den.policies.system-to-hm-outputs
  ];

  # Exclude den's built-in host-to-users (fleet user policies replace it).
  den.schema.host.excludes = [ den.policies.host-to-users ];
}
