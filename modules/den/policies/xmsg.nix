# xmsg federation membership (applications/dev/ai/mcp/xmsg.nix). A node's peers are
# the xmsg-nodes records these rules deliver to it, so every link exists on both
# ends by construction:
#   - same user: each of a user's nodes federates with that user's nodes on the
#     other hosts;
#   - trusted pairs: each pair's nodes federate across the two users, on every host;
#   - service nodes: a system service's node (services/matrix-xmsg.nix) federates with
#     its host's system owner's nodes, which its record names with the narrower
#     allow it grants them.
#
# The records come from a user-scoped aspect (mcp/xmsg.nix `xmsg-node`), not the
# xmsg aspect: that one is often a host include (roles.dev), and a host-included
# emitter never lands in the user's own scope, so a broadcast from it delivers
# nothing. Any new emitter for these rules belongs in a user-scoped aspect too.
{ den, lib, ... }:
let
  inherit (den.lib.policy) pipe;

  trustedPairs = [
    # vic can already take over sini's sessions (herdr-pair); messaging is no more.
    [
      "sini"
      "vic"
    ]
  ];
in
{
  den.policies.xmsg-same-user =
    { user, ... }:
    let
      src = user.name;
    in
    [
      (pipe.from "xmsg-nodes" [
        (pipe.broadcast ({ user, ... }: user.name == src))
      ])
    ];

  den.policies.xmsg-trusted-pairs =
    { user, ... }:
    let
      src = user.name;
      partners = lib.unique (
        lib.concatMap (pair: lib.optionals (lib.elem src pair) (lib.remove src pair)) trustedPairs
      );
    in
    lib.optionals (partners != [ ]) [
      (pipe.from "xmsg-nodes" [
        (pipe.broadcast ({ user, ... }: lib.elem user.name partners))
      ])
    ];

  # A service node is emitted at its host's scope. It reaches the owner's user scopes
  # by broadcast, and the host collects the owner's nodes back for the service's own
  # peers file. Clusters collect service nodes too: a pod leaf takes a service node
  # that guards through it as one more hub (kubernetes/services/ai/genie-guard.nix).
  den.policies.xmsg-service-nodes =
    { host, ... }:
    let
      owner = host.system-owner;
    in
    [
      (pipe.from "xmsg-nodes" [
        (pipe.broadcast ({ user, ... }: user.name == owner))
      ])
      (pipe.from "xmsg-nodes" [
        (pipe.collectAll ({ user, ... }: user.name == owner))
      ])
    ];

  den.policies.xmsg-cluster-service-nodes =
    { cluster, ... }:
    [
      (pipe.from "xmsg-nodes" [
        (pipe.collectAll ({ host, ... }: true))
      ])
    ];

  # Leaves are emitted by the cluster aspects that run them (kubernetes/services/ai/
  # genie-guard.nix); each hub keeps those that name it.
  den.policies.xmsg-collect-leaves =
    { host, ... }:
    [
      (pipe.from "xmsg-leaves" [
        (pipe.collectAll ({ cluster, ... }: true))
      ])
    ];

  den.schema.host.includes = [
    den.policies.xmsg-collect-leaves
    den.policies.xmsg-service-nodes
  ];
  den.schema.cluster.includes = [ den.policies.xmsg-cluster-service-nodes ];
  den.schema.user.includes = [
    den.policies.xmsg-same-user
    den.policies.xmsg-trusted-pairs
  ];
}
