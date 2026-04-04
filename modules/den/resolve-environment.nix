# Enrich den host objects before aspects see them.
# Resolves environment, ipv4/ipv6, cluster, and users (ACL-driven).
{
  den,
  self,
  config,
  lib,
  ...
}:
let
  inherit (den.lib.parametric) fixedTo;
  inherit (self.lib.users) resolveUsers;

  # Read from den-native environments (no cycle with config.hosts)
  denEnvironments = den.environments or { };
  allClusters = config.clusters or { };
  canonicalUsers = config.users or { };
  groupDefs = config.groups or { };

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

  # Resolve users for a host via ACL
  resolveHostUsers =
    host: env:
    let
      hostOptions = {
        hostname = host.name;
        inherit (host) system-access-groups;
        users = host.users or { };
      };
      resolved = resolveUsers lib canonicalUsers env hostOptions groupDefs;
      enabled = lib.filterAttrs (_: u: u.system.enable or false) resolved;
    in
    {
      all = resolved;
      inherit enabled;
      enabledNames = builtins.attrNames enabled;
    };

  enrichHost =
    host:
    let
      env = denEnvironments.${host.environment};
    in
    host
    // (extractIps host)
    // {
      environment = env;
      cluster = findCluster host;
      users = (host.users or { }) // (resolveHostUsers host env);
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
