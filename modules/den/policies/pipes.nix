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
    _:
    [
      (pipe.from "host-addrs" [
        (pipe.collectAll (_: true))
      ])
    ];

  den.policies.collect-bgp-peers =
    _:
    [
      (pipe.from "bgp-peers" [
        (pipe.collect (_: true))
      ])
    ];

  den.policies.collect-prometheus-targets =
    _:
    [
      (pipe.from "prometheus-targets" [
        (pipe.collect (_: true))
      ])
    ];

  den.policies.collect-k3s-nodes =
    _:
    [
      (pipe.from "k3s-nodes" [
        (pipe.collect (_: true))
      ])
    ];

  den.policies.collect-thunderbolt-mesh-peers =
    _:
    [
      (pipe.from "thunderbolt-mesh-peers" [
        (pipe.collect (_: true))
      ])
    ];

  den.policies.collect-vault-peers =
    _:
    [
      (pipe.from "vault-peers" [
        (pipe.collect (_: true))
      ])
    ];

  den.policies.collect-ollama-endpoints =
    _:
    [
      (pipe.from "ollama-endpoints" [
        (pipe.collect (_: true))
      ])
    ];

  # Cluster-scoped: collect k3s node data from hosts across all environments
  den.policies.cluster-collect-k3s-nodes =
    _:
    [
      (pipe.from "k3s-nodes" [
        (pipe.collectAll (_: true))
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
