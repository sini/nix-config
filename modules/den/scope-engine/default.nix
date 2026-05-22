# scope-engine integration: wire ACL + settings graphs into the module system.
#
# Exposes:
#   config.fleet.acl      — evaluated ACL graph (effectiveGates, resolveUser)
#   config.fleet.settings — evaluated settings cascade graph (resolvedSettings, setting)
{ lib, inputs, config, den, ... }:
let
  inherit (lib) mkOption types;

  engine = inputs.scope-engine { inherit lib; };

  acl = import ./acl.nix { inherit engine lib; };
  settings = import ./settings.nix { inherit engine lib; };

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

  config.fleet.acl = acl.build {
    groups = config.den.groups or { };
    environments = config.den.environments or { };
    hosts = flatHosts;
  };

  config.fleet.settings = settings.build {
    environments = config.den.environments or { };
    hosts = flatHosts;
    # Users not populated yet (Task 9) — pass empty for Phase 1.
    users = { };
  };
}
