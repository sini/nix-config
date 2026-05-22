# scope-engine integration: wire ACL + settings graphs into the module system.
#
# Exposes:
#   config.fleet.acl      — evaluated ACL graph (effectiveGates, resolveUser)
#   config.fleet.settings — evaluated settings cascade graph (resolvedSettings, setting)
{
  lib,
  config,
  den,
  aclGraph,
  settingsGraph,
  ...
}:
let
  inherit (lib) mkOption types;

  # Flatten den.hosts across all systems into a single attrset for graph construction.
  flatHosts = lib.foldl' (
    acc: system:
    acc // (den.hosts.${system} or { })
  ) { } (builtins.attrNames (den.hosts or { }));
in
{
  options.fleet.acl = mkOption {
    type = types.raw;
    description = "Evaluated ACL scope graph from scope-engine";
    readOnly = true;
  };

  options.fleet.settings = mkOption {
    type = types.raw;
    description = "Evaluated settings cascade graph from scope-engine";
    readOnly = true;
  };

  config.fleet.acl = aclGraph.build {
    groups = config.den.groups or { };
    environments = config.den.environments or { };
    hosts = flatHosts;
  };

  config.fleet.settings = settingsGraph.build {
    environments = config.den.environments or { };
    hosts = flatHosts;
    users = { };
  };
}
