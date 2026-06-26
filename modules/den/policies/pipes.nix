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
    { host, ... }:
    [
      (pipe.from "host-addrs" [
        (pipe.collectAll ({ host, ... }: true))
      ])
    ];

  den.policies.collect-bgp-peers =
    { host, ... }:
    [
      (pipe.from "bgp-peers" [
        (pipe.collect ({ host, ... }: true))
      ])
    ];

  den.policies.collect-prometheus-targets =
    { host, ... }:
    [
      (pipe.from "prometheus-targets" [
        (pipe.collect ({ host, ... }: true))
      ])
    ];

  den.policies.collect-k3s-nodes =
    { host, ... }:
    [
      (pipe.from "k3s-nodes" [
        (pipe.collect ({ host, ... }: true))
      ])
    ];

  den.policies.collect-container-registries =
    { host, ... }:
    [
      (pipe.from "container-registries" [
        (pipe.collect ({ host, ... }: true))
      ])
    ];

  den.policies.collect-thunderbolt-mesh-peers =
    { host, ... }:
    [
      (pipe.from "thunderbolt-mesh-peers" [
        (pipe.collect ({ host, ... }: true))
      ])
    ];

  den.policies.collect-vault-peers =
    { host, ... }:
    [
      (pipe.from "vault-peers" [
        (pipe.collect ({ host, ... }: true))
      ])
    ];

  den.policies.collect-ollama-endpoints =
    { host, ... }:
    [
      (pipe.from "ollama-endpoints" [
        (pipe.collect ({ host, ... }: true))
      ])
    ];

  # Cluster-scoped: collect k3s node data from host scopes across all environments.
  # The predicate must require `host` so findMatchingAll's entity kind filter
  # includes host scopes (a bare `_: true` has no entity args and rejects
  # all entity-typed scopes).
  den.policies.cluster-collect-k3s-nodes =
    { cluster, ... }:
    [
      (pipe.from "k3s-nodes" [
        (pipe.collectAll ({ host, ... }: true))
      ])
    ];

  den.policies.cluster-collect-media-scratch-exports =
    { cluster, ... }:
    [
      (pipe.from "media-scratch-exports" [
        (pipe.collectAll ({ host, ... }: true))
      ])
    ];

  den.policies.cluster-collect-container-registries =
    { cluster, ... }:
    [
      (pipe.from "container-registries" [
        (pipe.collectAll ({ host, ... }: true))
      ])
    ];

  # Bottom-up dual of the collect policies. `resolved-users` is emitted per user
  # at user scope (core/users/resolved-user-emitter.nix) and must bubble up the
  # P edge to the host so host aspects (wireshark, adb, ddcutil, razer,
  # remote-build-server, initrd-SSH) can enumerate the users resolved onto that
  # host. Exposed (not collected): the emit lives below the consumer, not beside
  # it. The emit is pipeline-parametric (`{ user, ... }:`), resolved to a concrete
  # record at the emitting user node before it crosses upward.
  den.policies.expose-resolved-users =
    { user, ... }:
    [
      (pipe.from "resolved-users" [
        pipe.expose
      ])
    ];

  # Push each user's Syncthing device record to that SAME user's scopes on other
  # hosts (a per-user mesh; users' meshes stay disjoint). Self-excluded by
  # broadcast; the member consumer drops self + id-less peers.
  den.policies.broadcast-syncthing-peers =
    { user, ... }:
    let
      srcUser = user.name;
    in
    [
      (pipe.from "syncthing-peers" [
        (pipe.broadcast ({ user, ... }: user.name == srcUser))
      ])
    ];

  den.schema.host.includes = [
    den.policies.collect-host-addrs
    den.policies.collect-bgp-peers
    den.policies.collect-prometheus-targets
    den.policies.collect-k3s-nodes
    den.policies.collect-container-registries
    den.policies.collect-thunderbolt-mesh-peers
    den.policies.collect-vault-peers
    den.policies.collect-ollama-endpoints
  ];

  den.schema.user.includes = [
    den.policies.expose-resolved-users
    den.policies.broadcast-syncthing-peers
  ];

  den.schema.cluster.includes = [
    den.policies.cluster-collect-k3s-nodes
    den.policies.cluster-collect-media-scratch-exports
    den.policies.cluster-collect-container-registries
  ];
}
