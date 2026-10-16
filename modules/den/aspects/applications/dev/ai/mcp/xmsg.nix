# xmsg (github:sini/xmsg): lists running agent sessions and delivers messages into
# them. Anonymous callers (scripts, CI, other hosts over ssh) use HTTP on loopback;
# agents use the `xmsg mcp` tools, whose send/reply go over agent.sock and are
# attested by SO_PEERCRED, so an agent can never claim another session's identity.
#
# The input SOURCE builds our own `xmsg` package (pkgs/by-name/xmsg), threaded to
# callPackage as `xmsg-src` by the overlay in pkgs/overlays.nix. The input's own
# home-manager module (homeManagerModules.xmsg) runs `xmsg serve` and installs each
# harness's pieces; this aspect sets what is the owner's: which harnesses, which
# services, and the federation peers with their allow lists.
#
# Federation: each user listed in a host's `federation.nodes` runs a node named
# `<user>.<host>` and federates with the nodes it lists as peers. A link is declared
# on both ends, each with what it allows the other. Nodes authenticate by CA (xmsg
# X16, federation plan §6.7): each presents a leaf signed by the host intermediate,
# whose URI SAN is its spiffe://json64.dev/host/<host>/user/<user> identity, and
# each peer entry trusts the root .crt with that one identity. The root and both
# intermediates are fleet-wide `intermediary` secrets under .secrets/xmsg-ca: only
# `agenix generate` decrypts them, never a host. The cluster intermediate is
# cert-manager's issuer (not wired here).
#
# Leaves (xmsg X19, federation plan §2.1): a node with `leaves` set is also the hub of
# those pods. Each is a CA peer marked `leaf`, so a send to
# `<ref>@<leaf>` is queued for the pod to collect and never pushed; its nodes' LAN
# addresses (pods masquerade to them) are admitted to the federation port.
#
# genie-guard (github:sini/genie-agent): on a host that runs the @genie bot, the
# owner's user service registers on this bus as the service genie-guard and answers guard-in
# requests with a model's verdict; xmsg admits that name only from its own binary.
{
  den,
  lib,
  self,
  ...
}:
let
  leafName = user: "xmsg-${user}-fed-ca";
  caDir = self + "/.secrets/xmsg-ca";
  spiffeOf = host: user: "spiffe://json64.dev/host/${host}/user/${user}";
  # A node's name derives from its identity (xmsg README 7.0): `<user>.<host>` for a host,
  # `<sa>.<ns>` for a pod. A CA peer entry must be keyed by it.
  nodeName = host: user: "${user}.${host}";
  # `<user>.<host>` -> the host entity, the user and that user's node settings there.
  nodeAt =
    name:
    let
      m = builtins.match "([^.]+)\\.(.+)" name;
      host = if m == null then null else den.hosts.x86_64-linux.${lib.elemAt m 1} or null;
      user = lib.elemAt m 0;
    in
    if host == null then
      throw "xmsg federation: peer ${name} is not <user>.<host> for a declared x86_64-linux host."
    else
      {
        inherit host user;
        node =
          (fedOf host).nodes.${user}
            or (throw "xmsg federation: ${host.name} declares no node for ${user}, so peer ${name} does not exist.");
      };
  leafNode =
    leaf:
    let
      m = builtins.match "spiffe://[^/]+/ns/([^/]+)/sa/([^/]+)" leaf.identity;
    in
    if m == null then
      throw "xmsg federation: leaf identity ${leaf.identity} is not spiffe://<domain>/ns/<ns>/sa/<sa>."
    else
      "${lib.elemAt m 1}.${lib.elemAt m 0}";
  fedOf = host: host.settings.applications.dev.ai.mcp.xmsg.federation;
  # A committed .crt sidecar, refused by name until generated. Copied alone, so a
  # path under `self` does not pull the whole flake source into the store path.
  caCrt =
    crt:
    if builtins.pathExists crt then
      builtins.path {
        path = crt;
        name = builtins.unsafeDiscardStringContext (baseNameOf crt);
      }
    else
      throw ''
        xmsg federation: ${toString crt} is absent. Declare the node in
        settings.applications.dev.ai.mcp.xmsg.federation.nodes, then run `agenix generate`,
        `git add` the .age and .crt files, and `agenix rekey`.
      '';
in
{
  # A hub admits its leaves' cluster nodes, which live in other environments, so it
  # needs every cluster's k3s-nodes, not only its siblings' (collect-k3s-nodes).
  den.policies.xmsg-collect-leaf-nodes =
    { host, ... }:
    lib.optionals (lib.any (n: n.leaves != [ ]) (lib.attrValues (fedOf host).nodes)) [
      (den.lib.policy.pipe.from "k3s-nodes" [
        (den.lib.policy.pipe.collectAll ({ host, ... }: true))
      ])
    ];

  den.schema.host.includes = [ den.policies.xmsg-collect-leaf-nodes ];

  flake-file.inputs.xmsg = {
    url = "github:sini/xmsg";
    inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  flake-file.inputs.genie-agent = {
    url = "github:sini/genie-agent";
    inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  den.aspects.applications.dev.ai.mcp.xmsg = {
    settings.genieGuard.ninferUrl = lib.mkOption {
      type = lib.types.strMatching "https?://.+";
      default = "http://10.9.2.2:18020/v1";
      description = "OpenAI-compatible endpoint genie-guard asks for its verdicts (hyperqwen on cortex-cuda).";
    };

    settings.federation.nodes = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            port = lib.mkOption {
              type = lib.types.port;
              default = 7788;
              description = "This node's federation listener port (federation plan §6.4); each node on a host needs its own.";
            };
            peers = lib.mkOption {
              type = lib.types.attrsOf (
                lib.types.submodule {
                  options.allow = lib.mkOption {
                    type = lib.types.listOf (
                      lib.types.enum [
                        "send"
                        "reply"
                        "list"
                      ]
                    );
                    default = [
                      "send"
                      "reply"
                      "list"
                    ];
                    description = "Operations the peer may perform on this node.";
                  };
                }
              );
              default = { };
              description = "Nodes this one federates with, keyed `<user>.<host>`. The peer must list this node too.";
            };
            leaves = lib.mkOption {
              type = lib.types.listOf (
                lib.types.submodule {
                  options = {
                    identity = lib.mkOption {
                      type = lib.types.str;
                      description = "The URI SAN of the leaf's certificate, signed under the xmsg CA root; spiffe://<domain>/ns/<ns>/sa/<sa> names the leaf `<sa>.<ns>`, and senders here address it as `<ref>@<sa>.<ns>`.";
                    };
                    cluster = lib.mkOption {
                      type = lib.types.str;
                      description = "The k3s cluster the leaf runs in; its nodes' addresses are admitted to the federation port.";
                    };
                    allow = lib.mkOption {
                      type = lib.types.listOf (
                        lib.types.enum [
                          "send"
                          "reply"
                          "list"
                        ]
                      );
                      default = [ "reply" ];
                      description = "Operations the leaf may perform here. A leaf collects its mailbox under any allow; `reply` answers what it collected.";
                    };
                    targets = lib.mkOption {
                      type = lib.types.listOf lib.types.str;
                      description = "Local targets this node queues for the leaf, each a service name or an instance ID (xmsg X14, checked when a send is queued).";
                    };
                  };
                }
              );
              default = [ ];
              description = "Pods this node is the hub of (xmsg X19).";
            };
          };
        }
      );
      default = { };
      description = "Users on this host that run an xmsg federation node, `<user>.<host>`, each with a CA-signed leaf `xmsg-<user>-fed-ca` in the host's secretPath. Declaring one needs `agenix generate`, `git add` of the .age and .crt files, and `agenix rekey`.";
    };

    nixos =
      {
        config,
        host,
        k3s-nodes,
        ...
      }:
      let
        nodes = (fedOf host).nodes;
        ca = name: deps: script: {
          rekeyFile = caDir + "/${name}.age";
          intermediary = true;
          generator = {
            inherit script;
            dependencies = deps;
          };
          settings.cn = "json64.dev xmsg ${name} CA";
        };
        root = config.age.secrets.xmsg-ca-root;
        self' = user: nodeName host.name user;
        leafRules = lib.concatStrings (
          lib.concatLists (
            lib.mapAttrsToList (
              _: node:
              lib.concatMap (
                leaf:
                let
                  ks = lib.filter (n: n.clusterName == leaf.cluster) k3s-nodes;
                in
                assert lib.assertMsg (
                  ks != [ ]
                ) "xmsg federation: leaf ${leafNode leaf}'s cluster ${leaf.cluster} has no nodes";
                map (n: ''
                  ip saddr ${n.ip} tcp dport ${toString node.port} accept comment "xmsg leaf ${leafNode leaf}: ${n.hostname}"
                '') (lib.sort (a: b: a.hostname < b.hostname) ks)
              ) node.leaves
            ) nodes
          )
        );
      in
      lib.mkIf (nodes != { }) {
        assertions =
          lib.concatLists (
            lib.mapAttrsToList (
              user: node:
              [
                {
                  assertion = config.users.users ? ${user};
                  message = "xmsg federation: ${host.name} declares a node for ${user}, who has no account here.";
                }
              ]
              ++ lib.mapAttrsToList (peer: _: {
                assertion = (nodeAt peer).node.peers ? ${self' user};
                message = "xmsg federation: ${self' user} lists ${peer}, which does not list ${self' user} back.";
              }) node.peers
            ) nodes
          )
          ++ [
            {
              assertion = lib.allUnique (lib.mapAttrsToList (_: n: n.port) nodes);
              message = "xmsg federation: two nodes on ${host.name} share a port.";
            }
          ];

        # No firewall rule for peers: the tailnet interface is trusted
        # (core.network.tailscale), so the ports are reachable over the tailnet and
        # nowhere else, and each CA identity admits only the peers listed.
        age.secrets = {
          xmsg-ca-root = ca "root" [ ] "x509-ca-root";
          xmsg-ca-host-intermediate = ca "host-intermediate" [ root ] "x509-ca-intermediate";
          xmsg-ca-cluster-intermediate = ca "cluster-intermediate" [ root ] "x509-ca-intermediate";
        }
        // lib.mapAttrs' (
          user: _:
          lib.nameValuePair (leafName user) {
            rekeyFile = host.secretPath + "/${leafName user}.age";
            generator = {
              script = "x509-spiffe-leaf";
              dependencies = [
                config.age.secrets.xmsg-ca-host-intermediate
                root
              ];
            };
            settings = {
              cn = "${user}@${host.name}";
              uri = spiffeOf host.name user;
            };
            owner = user;
            mode = "0400";
          }
        ) nodes;

        # Leaves reach the port over the LAN from their cluster's nodes. The rules are
        # nftables syntax, which the iptables backend ignores, leaving the port closed.
        networking.nftables.enable = lib.mkIf (lib.any (n: n.leaves != [ ]) (lib.attrValues nodes)) true;
        networking.firewall.extraInputRules = lib.mkIf (leafRules != "") leafRules;
      };

    # The bot's matrix skill, folded into every agent aspect that reads agent-extensions;
    # it ships with the bot, so it changes with the bot's protocol. The xmsg skill, MCP
    # entries, tool permissions, agy hook, pi extension and opencode plugin are the
    # xmsg module's (homeManagerModules.xmsg, harness switches below).
    agent-extensions =
      { inputs', ... }:
      {
        type = "skill";
        skills.matrix = inputs'.matrix-xmsg.packages.matrix-skill;
      };

    homeManagerModules = { inputs', ... }: [ inputs'.xmsg.homeManagerModules.xmsg ];

    homeManager =
      {
        config,
        environment,
        host,
        inputs',
        osConfig,
        pkgs,
        ...
      }:
      let
        # The @genie bot registers on this bus as the service matrix-xmsg on a host that
        # runs it; xmsg admits that name only from the bot's own binary.
        botEnabled = (host.settings.services.matrix-xmsg.rooms or [ ]) != [ ];
        guardEnabled = botEnabled && config.home.username == host.system-owner;
        guardExe = lib.getExe inputs'.genie-agent.packages.genie-guard;

        me = config.home.username;
        node = (fedOf host).nodes.${me} or null;
        rootCa = caCrt (caDir + "/root.crt");
        # Each entry trusts the root with the peer's one identity, keyed by the node name
        # that identity derives. A leaf entry's `address` is required but never dialled,
        # since sends to a leaf are queued and replies to it not pushed, so it names a host
        # that cannot resolve. No `from`: the host data carries no tailnet address.
        peers =
          lib.mapAttrs (
            name: p:
            let
              at = nodeAt name;
            in
            {
              address = "${at.host.name}.ts.${environment.domain}:${toString at.node.port}";
              inherit (p) allow;
              ca = rootCa;
              identities = [ (spiffeOf at.host.name at.user) ];
            }
          ) node.peers
          // lib.listToAttrs (
            map (
              leaf:
              lib.nameValuePair (leafNode leaf) {
                address = "${leafNode leaf}.invalid:${toString node.port}";
                ca = rootCa;
                identities = [ leaf.identity ];
                leaf = true;
                inherit (leaf) allow targets;
              }
            ) node.leaves
          );
      in
      {
        programs.xmsg = {
          enable = true;
          # Linux runs our own build (pkgs/by-name/xmsg, also the genie tiers' bus); it is
          # Linux-only, so darwin takes the module's default, the input's own package.
          package = lib.mkIf pkgs.stdenv.hostPlatform.isLinux pkgs.local.xmsg;
          # darwin (patch) runs no `xmsg serve`; its harnesses still get their pieces.
          server = {
            enable = pkgs.stdenv.hostPlatform.isLinux;
            svcExe =
              lib.optionalAttrs botEnabled {
                matrix-xmsg = lib.getExe inputs'.matrix-xmsg.packages.default;
              }
              // lib.optionalAttrs guardEnabled { genie-guard = guardExe; };
            federation = lib.mkIf (node != null) {
              enable = true;
              inherit (node) port;
              inherit peers;
              cert = caCrt (host.secretPath + "/${leafName me}.crt");
              key = osConfig.age.secrets.${leafName me}.path;
            };
          };
          harnesses =
            lib.genAttrs
              [
                "claude"
                "agy"
                "pi"
                "opencode"
                "hermes"
              ]
              (_: {
                enable = true;
              });
        };

        # The api-key file is the hyperqwen home-manager secret, decrypted for the owner.
        systemd.user.services.genie-guard = lib.mkIf guardEnabled {
          Unit = {
            Description = "genie-guard: guard-in verdicts for the @genie bot";
            After = [ "xmsg.service" ];
            Wants = [ "xmsg.service" ];
          };
          Service = {
            ExecStart = lib.escapeShellArgs [
              guardExe
              "--ninfer-url"
              host.settings.applications.dev.ai.mcp.xmsg.genieGuard.ninferUrl
              "--api-key-file"
              "%h/.config/hyperqwen/api-key"
            ];
            Restart = "on-failure";
            RestartSec = 10;
          };
          Install.WantedBy = [ "default.target" ];
        };
      };
  };
}
