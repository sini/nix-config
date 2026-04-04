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
  allClusters = config.clusters or { };

  # Extract primary IPs from networking interfaces (matching old host type)
  extractIps =
    host:
    let
      interfaces = host.networking.interfaces or { };
      ifNames = builtins.attrNames interfaces;
      firstIf = if ifNames != [ ] then interfaces.${builtins.head ifNames} else { };
      stripCidr = addr: builtins.head (lib.splitString "/" addr);
    in
    {
      ipv4 = map stripCidr (firstIf.ipv4 or [ ]);
      ipv6 = firstIf.ipv6 or [ ];
    };

  # Find the cluster this host belongs to (if any)
  findCluster =
    host: lib.findFirst (c: c.resolvedHosts ? ${host.name}) null (builtins.attrValues allClusters);

  enrichHost =
    host:
    host
    // (extractIps host)
    // {
      environment = allEnvironments.${host.environment};
      cluster = findCluster host;
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
