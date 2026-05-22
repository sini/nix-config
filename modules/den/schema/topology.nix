# Entity topology: parent-child relationships between kinds.
# Used by gen-schema's buildInstanceGraph to generate scope-engine parent edges.
{ ... }:
{
  den.schema._topology = {
    environment.children = [
      "host"
      "cluster"
    ];
    host.children = [ "user" ];
  };
}
