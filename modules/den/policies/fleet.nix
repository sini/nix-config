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

  inherit (config) environments;
in
{
  # flake -> fleet: single fleet entity.
  den.policies.to-fleet = _: [
    (resolve.to "fleet" {
      fleet = {
        name = "fleet";
      };
    })
  ];

  # fleet -> environments: fan out per registered environment.
  den.policies.fleet-to-envs =
    _:
    lib.mapAttrsToList (
      _: env:
      resolve.to "environment" {
        environment = env;
      }
    ) environments;

  # environment -> hosts: walk den.hosts whose environment matches.
  den.policies.env-to-hosts =
    { environment, ... }:
    lib.concatMap (
      system:
      lib.concatMap (
        hostName:
        let
          hostCfg = den.hosts.${system}.${hostName};
        in
        lib.optionals ((hostCfg.environment or "prod") == environment.name && hostCfg.intoAttr != [ ]) [
          (resolve.to "host" { host = hostCfg; })
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
