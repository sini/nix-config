# Pipe collection policies for cross-host discovery.
#
# Declares collection policies for all quirks that need cross-host
# aggregation, wired into host schema so every host collects pipe
# entries from peers.
{ den, ... }:
let
  inherit (den.lib.policy) pipe;
in
{
  den.policies.collect-host-addrs =
    { ... }:
    [
      (pipe.from "host-addrs" [
        (pipe.collectAll ({ ... }: true))
      ])
    ];

  den.policies.collect-bgp-peers =
    { ... }:
    [
      (pipe.from "bgp-peers" [
        (pipe.collect ({ ... }: true))
      ])
    ];

  den.policies.collect-prometheus-targets =
    { ... }:
    [
      (pipe.from "prometheus-targets" [
        (pipe.collect ({ ... }: true))
      ])
    ];

  den.policies.collect-k3s-nodes =
    { ... }:
    [
      (pipe.from "k3s-nodes" [
        (pipe.collect ({ ... }: true))
      ])
    ];

  den.policies.collect-thunderbolt-mesh-peers =
    { ... }:
    [
      (pipe.from "thunderbolt-mesh-peers" [
        (pipe.collect ({ ... }: true))
      ])
    ];

  den.policies.collect-vault-peers =
    { ... }:
    [
      (pipe.from "vault-peers" [
        (pipe.collect ({ ... }: true))
      ])
    ];

  den.policies.collect-ollama-endpoints =
    { ... }:
    [
      (pipe.from "ollama-endpoints" [
        (pipe.collect ({ ... }: true))
      ])
    ];

  # Cluster-scoped: collect k3s node data from hosts across all environments
  den.policies.cluster-collect-k3s-nodes =
    { ... }:
    [
      (pipe.from "k3s-nodes" [
        (pipe.collectAll ({ ... }: true))
      ])
    ];

  den.schema.host.includes = [
    den.policies.collect-host-addrs
    den.policies.collect-bgp-peers
    den.policies.collect-prometheus-targets
    den.policies.collect-k3s-nodes
    den.policies.collect-thunderbolt-mesh-peers
    den.policies.collect-vault-peers
    den.policies.collect-ollama-endpoints
  ];

  den.schema.cluster.includes = [
    den.policies.cluster-collect-k3s-nodes
  ];
}
