# Enrich den host objects with resolved environment before aspects see them.
# This avoids infinite recursion (can't put config.environments on den.hosts directly)
# while ensuring aspects access host.environment as a full attrset.
{
  den,
  config,
  lib,
  ...
}:
let
  inherit (den.lib.parametric) fixedTo;
  allEnvironments = config.environments;

  enrichHost =
    host:
    host
    // {
      environment = allEnvironments.${host.environment};
    };
in
{
  den.ctx.host = {
    provides.host = lib.mkForce (
      { host }: fixedTo { host = enrichHost host; } den.aspects.${host.aspect}
    );

    into.user = lib.mkForce (
      { host }:
      map (user: {
        host = enrichHost host;
        inherit user;
      }) (lib.attrValues host.users)
    );

    into.default = lib.mkForce ({ host }: [ { host = enrichHost host; } ]);
  };
}
