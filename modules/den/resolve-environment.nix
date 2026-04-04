# Enrich den host objects before aspects see them.
# Resolves environment (from den.environments), computes ipv4/ipv6, finds cluster.
{
  den,
  config,
  lib,
  ...
}:
let
  inherit (den.lib.parametric) fixedTo;

  # Read from den-native environments (no cycle with config.hosts)
  denEnvironments = den.environments or { };
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
    host:
    lib.findFirst (c: (c.resolvedHosts or { }) ? ${host.name}) null (builtins.attrValues allClusters);

  enrichHost =
    host:
    host
    // (extractIps host)
    // {
      environment = denEnvironments.${host.environment};
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
