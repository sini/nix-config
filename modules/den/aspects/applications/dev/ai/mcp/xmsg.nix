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
# Federation: the system owner's node on each host of `fedPair` federates with the
# other's over pinned mTLS (xmsg-links `sini.bitstream ↔ sini.cortex : send, reply,
# list`, federation plan §6.1). The node key is an `xmsg-identity` agenix secret
# whose public .crt sidecar is committed beside the .age; the peer's pin is computed
# from that .crt at build time.
#
# With federation.ca.enable on both, the pair authenticates by CA instead (xmsg X16,
# federation plan §6.7): each node presents a leaf signed by the host intermediate,
# whose URI SAN is its spiffe://json64.dev/host/<host>/user/<user> identity, and
# each peer entry trusts the root .crt with that one identity. The root and both
# intermediates are fleet-wide `intermediary` secrets under .secrets/xmsg-ca: only
# `agenix generate` decrypts them, never a host. The cluster intermediate is
# cert-manager's issuer (not wired here).
#
# Leaves (xmsg X19, federation plan §2.1): with federation.leaves set, the owner's node
# is also the hub of those pods. Each is a CA peer marked `leaf`, so a send to
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
  fedPair = [
    "bitstream"
    "cortex"
  ];
  keyName = "xmsg-sini";
  leafName = "${keyName}-fed-ca";
  caDir = self + "/.secrets/xmsg-ca";
  spiffeOf = host: "spiffe://json64.dev/host/${host.name}/user/${host.system-owner}";
  # A node's name derives from its identity (xmsg README 7.0): `<user>.<host>` for a host,
  # `<sa>.<ns>` for a pod. A CA peer entry must be keyed by it.
  nodeOf = host: "${host.system-owner}.${host.name}";
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
  peerOf = host: den.hosts.x86_64-linux.${lib.head (lib.remove host.name fedPair)};
  # The committed public half of a host's node key, refused by name until generated.
  crtOf =
    host:
    let
      crt = host.secretPath + "/${keyName}.crt";
    in
    if builtins.pathExists crt then
      crt
    else
      throw ''
        xmsg federation: ${host.name} has no node certificate ${keyName}.crt in its secretPath.
        Set settings.applications.dev.ai.mcp.xmsg.federation.enable on ${lib.concatStringsSep " and " fedPair}
        (it declares each node key), then run `agenix generate`, `git add` the .age and .crt
        files, and `agenix rekey`.
      '';
  # A committed CA .crt sidecar, refused by name until generated. Copied alone, so a
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
        xmsg federation: ${toString crt} is absent. Set
        settings.applications.dev.ai.mcp.xmsg.federation.ca.enable on ${lib.concatStringsSep " and " fedPair},
        then run `agenix generate`, `git add` the .age and .crt files, and `agenix rekey`.
      '';
in
{
  # A hub admits its leaves' cluster nodes, which live in other environments, so it
  # needs every cluster's k3s-nodes, not only its siblings' (collect-k3s-nodes).
  den.policies.xmsg-collect-leaf-nodes =
    { host, ... }:
    lib.optionals ((host.settings.applications.dev.ai.mcp.xmsg.federation.leaves or [ ]) != [ ]) [
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

    settings.federation = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Federate the system owner's xmsg with its fedPair peer. agenix-rekey refuses to evaluate a declared key whose .age is absent, and `agenix generate` creates only declared ones, so set this on both hosts, then run `agenix generate`, `git add` the .age and .crt files, and `agenix rekey`.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 7788;
        description = "The owner node's federation listener port (federation plan §6.4).";
      };
      ca.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Declare the xmsg CA (root, host and cluster intermediates under .secrets/xmsg-ca) and this host's CA-signed leaf, and federate with them instead of the pinned node key. Set it on both fedPair hosts, then run `agenix generate`, `git add` the .age and .crt files, and `agenix rekey`.";
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
        description = "Pods this owner node is the hub of (xmsg X19). Needs ca.enable.";
      };
    };

    nixos =
      {
        config,
        environment,
        host,
        k3s-nodes,
        ...
      }:
      let
        fed = fedOf host;
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
      in
      lib.mkMerge [
        (lib.mkIf fed.enable {
          assertions = [
            {
              assertion = lib.elem host.name fedPair;
              message = "xmsg federation: ${host.name} is not in fedPair (${toString fedPair}).";
            }
            {
              assertion = fed.ca.enable -> (fedOf (peerOf host)).ca.enable;
              message = "xmsg federation: ca.enable is set on ${host.name} but not on its peer; set it on both.";
            }
            {
              assertion = fed.leaves != [ ] -> fed.ca.enable;
              message = "xmsg federation: leaves on ${host.name} authenticate by the xmsg CA; set ca.enable.";
            }
          ];

          # No firewall rule for the peer: the tailnet interface is trusted
          # (core.network.tailscale), so the port is reachable over the tailnet and
          # nowhere else, and the pin or the CA identity admits only the peer.
        })

        # Leaves reach the port over the LAN from their cluster's nodes. The rules are
        # nftables syntax, which the iptables backend ignores, leaving the port closed.
        (lib.mkIf (fed.enable && fed.leaves != [ ]) {
          networking.nftables.enable = true;
          networking.firewall.extraInputRules = lib.concatStrings (
            lib.concatMap (
              leaf:
              let
                nodes = lib.filter (n: n.clusterName == leaf.cluster) k3s-nodes;
              in
              assert lib.assertMsg (
                nodes != [ ]
              ) "xmsg federation: leaf ${leafNode leaf}'s cluster ${leaf.cluster} has no nodes";
              map (n: ''
                ip saddr ${n.ip} tcp dport ${toString fed.port} accept comment "xmsg leaf ${leafNode leaf}: ${n.hostname}"
              '') (lib.sort (a: b: a.hostname < b.hostname) nodes)
            ) fed.leaves
          );
        })

        (lib.mkIf (fed.enable && !fed.ca.enable) {
          age.secrets.${keyName} = {
            rekeyFile = host.secretPath + "/${keyName}.age";
            generator.script = "xmsg-identity";
            settings = {
              node = "${host.system-owner}@${host.name}";
              san = "${host.name}.ts.${environment.domain}";
            };
            owner = host.system-owner;
            mode = "0400";
          };
        })

        (lib.mkIf fed.ca.enable {
          age.secrets = {
            xmsg-ca-root = ca "root" [ ] "x509-ca-root";
            xmsg-ca-host-intermediate = ca "host-intermediate" [ root ] "x509-ca-intermediate";
            xmsg-ca-cluster-intermediate = ca "cluster-intermediate" [ root ] "x509-ca-intermediate";
            ${leafName} = {
              rekeyFile = host.secretPath + "/${leafName}.age";
              generator = {
                script = "x509-spiffe-leaf";
                dependencies = [
                  config.age.secrets.xmsg-ca-host-intermediate
                  root
                ];
              };
              settings = {
                cn = "${host.system-owner}@${host.name}";
                uri = spiffeOf host;
              };
              owner = host.system-owner;
              mode = "0400";
            };
          };
        })
      ];

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

        fed = fedOf host;
        peer = peerOf host;
        rootCa = caCrt (caDir + "/root.crt");
        # Under ca.enable the entry trusts the root with the peer's one identity, keyed by the
        # node name that identity derives. A pinned entry keeps the host name as its
        # nickname. A leaf entry's `address` is required but never dialled, since sends to
        # a leaf are queued and replies to it not pushed, so it names a host that cannot
        # resolve. No `from`: the host data carries no tailnet address.
        peerEntry = {
          address = "${peer.name}.ts.${environment.domain}:${toString (fedOf peer).port}";
          allow = [
            "send"
            "reply"
            "list"
          ];
        };
        peers =
          if fed.ca.enable then
            {
              ${nodeOf peer} = peerEntry // {
                ca = rootCa;
                identities = [ (spiffeOf peer) ];
              };
            }
            // lib.listToAttrs (
              map (
                leaf:
                lib.nameValuePair (leafNode leaf) {
                  address = "${leafNode leaf}.invalid:${toString fed.port}";
                  ca = rootCa;
                  identities = [ leaf.identity ];
                  leaf = true;
                  inherit (leaf) allow targets;
                }
              ) fed.leaves
            )
          else
            {
              ${peer.name} = peerEntry // {
                pinFromCert = crtOf peer;
              };
            };
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
            federation = lib.mkIf (fed.enable && config.home.username == host.system-owner) {
              enable = true;
              inherit (fed) port;
              inherit peers;
              cert = if fed.ca.enable then caCrt (host.secretPath + "/${leafName}.crt") else crtOf host;
              key = osConfig.age.secrets.${if fed.ca.enable then leafName else keyName}.path;
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
