# Enrich den host objects before aspects see them.
# Resolves environment, cluster, and users (ACL-driven).
# Note: ipv4/ipv6 are now computed by den.schema.host.
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

  denEnvironments = den.environments or { };
  allClusters = config.clusters or { };
  canonicalUsers = config.users or { };
  groupDefs = config.groups or { };

  findCluster =
    host:
    lib.findFirst (c: (c.resolvedHosts or { }) ? ${host.name}) null (builtins.attrValues allClusters);

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
    // {
      environment = env;
      cluster = findCluster host;
      resolvedUsers = resolveHostUsers host env;
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
