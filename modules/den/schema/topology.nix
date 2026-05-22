# Entity topology via parent sidecars.
# Declares parent-child nesting between kinds for scope-engine graph generation.
# gen-schema derives _meta.topology from these declarations.
{ ... }:
{
  den.schema.host.parent = "environment";
  den.schema.cluster.parent = "environment";
  den.schema.user.parent = "host";
}
