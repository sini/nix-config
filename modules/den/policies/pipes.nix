# Pipe collection policies for cross-host discovery.
#
# Declares collection policies for all quirks that need cross-host
# aggregation, wired into host schema so every host collects pipe
# entries from peers.
{ den, lib, ... }:
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

  den.policies.collect-ninfer-endpoints =
    { host, ... }:
    [
      (pipe.from "ninfer-endpoints" [
        (pipe.collect ({ host, ... }: true))
      ])
    ];

  den.policies.collect-hipfire-endpoints =
    { host, ... }:
    [
      (pipe.from "hipfire-endpoints" [
        (pipe.collect ({ host, ... }: true))
      ])
    ];

  # IdP identities to hosts, for host services that authorize by kanidm group
  # (services/matrix-xmsg.nix). Consumers filter by environment.
  den.policies.collect-idm-users =
    { host, ... }:
    [
      (pipe.from "idm-users" [
        (pipe.collectAll ({ host, ... }: true))
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

  # Host-scope emits (nginx vhosts) reach the cluster here; the cluster's own
  # gateway-served emits are already in its scope. The consumer filters by
  # environment, as with k3s-nodes.
  den.policies.cluster-collect-served-domains =
    { cluster, ... }:
    [
      (pipe.from "served-domains" [
        (pipe.collectAll ({ host, ... }: true))
      ])
    ];

  # A host's public-ingress endpoint (its nginx) to clusters, where the gateway
  # routes that host's served-domains names to it. Consumers filter by environment.
  den.policies.cluster-collect-gateway-upstreams =
    { cluster, ... }:
    [
      (pipe.from "gateway-upstreams" [
        (pipe.collectAll ({ host, ... }: true))
      ])
    ];

  # IdP identities (kanidm persons and their groups) from the IdP host to clusters,
  # so cluster workloads can derive authorization (e.g. Synapse admins) from the
  # same provisioning kanidm applies. Consumers filter by environment.
  den.policies.cluster-collect-idm-users =
    { cluster, ... }:
    [
      (pipe.from "idm-users" [
        (pipe.collectAll ({ host, ... }: true))
      ])
    ];

  # Scrape targets to clusters, so the cluster's Prometheus can find hosts that
  # announce services it talks to (e.g. the outside Alertmanager). Consumers
  # filter by environment.
  den.policies.cluster-collect-prometheus-targets =
    { cluster, ... }:
    [
      (pipe.from "prometheus-targets" [
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

  # Domain-entity quirks (modules/den/aspects/domain/domain.nix). A domain has no
  # environment, so every collect takes every domain's records; consumers filter.
  # Clusters' telemetry ingest endpoints to hosts; each host's Alloy pushes to
  # the one its environment names (environment.monitoring.ingest).
  den.policies.collect-monitoring-ingest =
    { host, ... }:
    [
      (pipe.from "monitoring-ingest" [
        (pipe.collectAll ({ cluster, ... }: true))
      ])
    ];

  den.policies.collect-certificate-domains =
    { host, ... }:
    [
      (pipe.from "certificate-domains" [
        (pipe.collectAll ({ domain, ... }: true))
      ])
    ];

  den.policies.cluster-collect-domain-quirks =
    { cluster, ... }:
    map
      (
        quirk:
        pipe.from quirk [
          (pipe.collectAll ({ domain, ... }: true))
        ]
      )
      [
        "certificate-domains"
        "apex-domains"
        "site-domains"
      ];

  # Public DNS (modules/flake-parts/terranix): the zones and zone records from
  # every domain, and the served names of hosts and clusters in every
  # environment. A collectAll predicate matches only the entity kind it names,
  # so each kind takes its own collect.
  den.policies.env-collect-dns =
    { environment, ... }:
    [
      (pipe.from "dns-zones" [ (pipe.collectAll ({ domain, ... }: true)) ])
      (pipe.from "dns-records" [ (pipe.collectAll ({ domain, ... }: true)) ])
      (pipe.from "served-domains" [ (pipe.collectAll ({ host, ... }: true)) ])
      (pipe.from "served-domains" [ (pipe.collectAll ({ cluster, ... }: true)) ])
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

  # Broadcast each replicating user's dir set to the hub. den PR #625 surfaces the
  # home-pool `replicateHome` at the user scope, so a user-scope policy reads it; a
  # source-side transform tags each dir record with the user (the hub namespaces
  # folders per user). Delivered under `replicateHome` to the single isHub host.
  den.policies.broadcast-syncthing-hub-shares =
    { user, ... }:
    let
      srcUser = user.name;
    in
    [
      (pipe.from "replicateHome" [
        (pipe.transform (entry: {
          user = srcUser;
          directories = entry.directories or [ ];
        }))
        (pipe.broadcast ({ host, ... }: host.settings.core.network.syncthing.isHub or false))
      ])
    ];

  # Each member's device record also reaches the hub so it can connect to and back
  # up every member (the same record the same-user mesh gets, pushed to the hub).
  den.policies.broadcast-syncthing-peers-to-hub =
    { ... }:
    [
      (pipe.from "syncthing-peers" [
        (pipe.broadcast ({ host, ... }: host.settings.core.network.syncthing.isHub or false))
      ])
    ];

  # The hub advertises its OWN device record (its host-scope `syncthing-peers`
  # emit; received member records are not re-broadcast) to every member so members
  # add it and share their folders with it.
  den.policies.broadcast-hub-peer =
    { host, ... }:
    lib.optionals (host.settings.core.network.syncthing.isHub or false) [
      (pipe.from "syncthing-peers" [
        (pipe.broadcast ({ user, ... }: true))
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
    den.policies.collect-ninfer-endpoints
    den.policies.collect-hipfire-endpoints
    den.policies.broadcast-hub-peer
    den.policies.collect-certificate-domains
    den.policies.collect-monitoring-ingest
    den.policies.collect-idm-users
  ];

  den.schema.user.includes = [
    den.policies.expose-resolved-users
    den.policies.broadcast-syncthing-peers
    den.policies.broadcast-syncthing-peers-to-hub
    den.policies.broadcast-syncthing-hub-shares
  ];

  den.schema.environment.includes = [ den.policies.env-collect-dns ];

  den.schema.cluster.includes = [
    den.policies.cluster-collect-k3s-nodes
    den.policies.cluster-collect-media-scratch-exports
    den.policies.cluster-collect-container-registries
    den.policies.cluster-collect-served-domains
    den.policies.cluster-collect-gateway-upstreams
    den.policies.cluster-collect-idm-users
    den.policies.cluster-collect-prometheus-targets
    den.policies.cluster-collect-domain-quirks
  ];
}
