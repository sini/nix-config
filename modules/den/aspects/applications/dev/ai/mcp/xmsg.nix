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
# `<user>.<host>`. Its peers are derived, never listed: the node emits an xmsg-nodes
# record, and the peering rules (policies/xmsg.nix: same user, trusted pairs)
# deliver it to the nodes that federate with it, so each link exists on both ends by
# construction. Nodes authenticate by CA (xmsg
# X16, federation plan §6.7): each presents a leaf signed by the host intermediate,
# whose URI SAN is its spiffe://<environment domain>/host/<host>/user/<user> identity, and
# each peer entry trusts the root .crt with that one identity. The root and both
# intermediates are fleet-wide `intermediary` secrets under .secrets/xmsg-ca: only
# `agenix generate` decrypts them, never a host. The cluster intermediate is
# cert-manager's issuer (not wired here).
#
# Leaves (xmsg X19, federation plan §2.1): a cluster aspect running a leaf pod emits an
# xmsg-leaves record naming the nodes it wants as hubs; each of those nodes takes it
# as a CA peer marked `leaf`, so a send to `<ref>@<leaf>` is queued for the pod to
# collect and never pushed, and admits the cluster's node addresses (pods masquerade
# to them) to its federation port.
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
  xl = import ./_xmsg-lib.nix { inherit lib self; };
  # TRANSITION SHIM (xmsg PR-A, 912ca97a; removed with xmsg-mqsh): the scripts that keep
  # the legacy socket path <rt>/xmsg linked to xmsg's managed namespace, given the
  # platform's legacy path and namespace parent as shell (`legacy`, `parent`).
  legacyShim =
    pkgs: legacyEnv:
    let
      # A socket counts as live only if connect() succeeds (never mtime).
      liveSocket = ''
        live() { ${lib.getExe pkgs.socat} -u OPEN:/dev/null "UNIX-CONNECT:$1" 2>/dev/null; }
      '';
      # <rt>/xmsg stays one persistent 0700 directory: a sandbox that bind-mounts it
      # (genie-agent's units) keeps the directory it mounted, so it is never removed and
      # recreated. Clearing it drops dead entries; a live one, or anything that is not a
      # socket or a link, refuses. A directory-level link (the shim's first form) is
      # unlinked, never followed.
      clearLegacy = ''
        ${liveSocket}
        if [ -L "$legacy" ]; then
          for s in http agent register; do
            if live "$legacy/$s.sock"; then echo "xmsg-legacy: $legacy/$s.sock is live; refusing to start" >&2; exit 1; fi
          done
          rm -f -- "$legacy"
        fi
        if [ -d "$legacy" ]; then
          for e in "$legacy"/* "$legacy"/.[!.]*; do
            [ -e "$e" ] || [ -L "$e" ] || continue
            if [ ! -S "$e" ] && [ ! -L "$e" ]; then
              echo "xmsg-legacy: $e is not a socket or link; leaving it, refusing to start" >&2; exit 1
            fi
            if live "$e"; then echo "xmsg-legacy: $e is live; refusing to start" >&2; exit 1; fi
            rm -f -- "$e"
          done
        else
          mkdir -m 0700 -- "$legacy"
        fi
      '';
      # Its own PATH: a launchd agent's is minimal, and a user unit's is the manager's.
      shimPath = ''
        export PATH=${
          lib.makeBinPath [
            pkgs.coreutils
            pkgs.gnugrep
            pkgs.findutils
          ]
        }:/usr/bin:/bin
      '';
      legacyPre = pkgs.writeShellScript "xmsg-legacy-pre" ''
        set -eu
        ${shimPath}
        ${legacyEnv}
        ${clearLegacy}
      '';
      legacyLink = pkgs.writeShellScript "xmsg-legacy-link" ''
        set -eu
        ${shimPath}
        ${legacyEnv}
        ${liveSocket}
        uid=$(id -u)
        # The daemon's namespace is the one whose agent socket accepts. Other xmsg-<uid>-*
        # directories can share the parent (on darwin /tmp, every test run's state root
        # leaves one), and a stale socket file from the previous run exists before the new
        # daemon has bound it.
        for _ in $(seq 1 60); do
          n=0; ns=
          for d in "$parent"/xmsg-"$uid"-*; do
            if [ -d "$d" ] && live "$d/agent.sock"; then n=$((n + 1)); ns=$d; fi
          done
          [ "$n" -ge 1 ] && break
          sleep 1
        done
        if [ "$n" -ne 1 ]; then
          echo "xmsg-legacy: expected exactly one live $parent/xmsg-$uid-* namespace, found $n" >&2; exit 1
        fi
        # Hard links to the namespace's sockets: clients before PR-A refuse a socket
        # directory that is a symlink, and a symlinked socket would point outside a
        # sandbox that binds only this directory. Each name is swapped in by rename.
        linked() {
          [ -d "$legacy" ] && [ ! -L "$legacy" ] || return 1
          for s in http agent register; do
            # -ef follows a symlink, so a symlinked socket must fail here explicitly.
            [ ! -L "$legacy/$s.sock" ] && [ "$legacy/$s.sock" -ef "$ns/$s.sock" ] || return 1
          done
        }
        if linked; then exit 0; fi
        if [ -L "$legacy" ]; then rm -f -- "$legacy"; fi
        if [ ! -d "$legacy" ]; then mkdir -m 0700 -- "$legacy"; fi
        for s in http agent register; do
          ln -f -- "$ns/$s.sock" "$legacy/.$s.sock.new"
          mv -f -- "$legacy/.$s.sock.new" "$legacy/$s.sock"
        done
        echo "xmsg-legacy: $legacy/{http,agent,register}.sock = $ns (hard links)"
      '';
    in
    {
      pre = legacyPre;
      link = legacyLink;
    };
  inherit (xl)
    leafName
    caDir
    spiffeOf
    nodeName
    caCrt
    ;
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

  # The federation secrets of a host's nodes, the same on NixOS and darwin: the CA
  # chain (intermediary, only `agenix generate` decrypts it) and each node's leaf.
  fedSecrets =
    {
      config,
      environment,
      host,
    }:
    let
      caName =
        if environment.xmsg.caName == null then
          throw "xmsg federation: ${host.name} declares a node, so environment ${environment.name} needs xmsg.caName."
        else
          environment.xmsg.caName;
      ca = name: deps: script: {
        rekeyFile = caDir + "/${name}.age";
        intermediary = true;
        generator = {
          inherit script;
          dependencies = deps;
        };
        settings.cn = "${caName} ${name} CA";
      };
      root = config.age.secrets.xmsg-ca-root;
    in
    {
      xmsg-ca-root = ca "root" [ ] "x509-ca-root";
      xmsg-ca-host-intermediate = ca "host-intermediate" [ root ] "x509-ca-intermediate";
      xmsg-ca-cluster-intermediate = ca "cluster-intermediate" [ root ] "x509-ca-intermediate";
    }
    // lib.mapAttrs' (
      user: _:
      lib.nameValuePair (leafName user) (
        xl.leafSecret {
          inherit config host user;
          inherit (environment) domain;
        }
      )
    ) (fedOf host).nodes
    // lib.optionalAttrs (fedOf host).collector.enable (
      let
        user = (fedOf host).collector.user;
      in
      {
        ${collectorLeafName user} =
          xl.leafSecret {
            inherit config host user;
            inherit (environment) domain;
          }
          // {
            rekeyFile = host.secretPath + "/${collectorLeafName user}.age";
            settings = {
              cn = "${user}@collector";
              uri = spiffeOf environment.domain "collector" user;
            };
          };
      }
    );
  collectorLeafName = user: "xmsg-${user}-collector-ca";
in
{
  # A hub admits its leaves' cluster nodes, which live in other environments, so it
  # needs every cluster's k3s-nodes, not only its siblings' (collect-k3s-nodes).
  den.policies.xmsg-collect-leaf-nodes =
    { host, ... }:
    lib.optionals ((fedOf host).nodes != { }) [
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

  # This user's node here, for the peering rules (policies/xmsg.nix) to deliver. A
  # user-scoped aspect, so the record is emitted at the user's own scope, where a
  # broadcast picks it up (the syncthing `peer` pattern); the xmsg aspect itself is
  # often a host include.
  den.aspects.applications.dev.ai.mcp.xmsg-node.xmsg-nodes =
    {
      environment,
      host,
      user,
      ...
    }:
    lib.optionals ((fedOf host).nodes ? ${user.name}) [
      {
        name = nodeName host.name user.name;
        address = "${host.name}.ts.${environment.domain}:${toString (fedOf host).nodes.${user.name}.port}";
        identity = spiffeOf environment.domain host.name user.name;
      }
    ];

  den.schema.user.includes = [ den.aspects.applications.dev.ai.mcp.xmsg-node ];

  # Who a user federates with beyond their own nodes (policies/xmsg.nix), read both
  # ways: naming a user in either's list makes the pair.
  den.schema.user.imports = [
    {
      options.xmsg.trusts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "alice" ];
        description = "Users whose xmsg nodes federate with this user's, on every host; the only other users whose service nodes this user's nodes may peer.";
      };
    }
  ];

  # The federation CA's common names, `<caName> <ca> CA`. The CA is one per fleet
  # (.secrets/xmsg-ca), so every environment with a node names it the same.
  den.schema.environment.imports = [
    {
      options.xmsg.caName = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "example.org xmsg";
        description = "Prefix of the xmsg federation CA common names (`<caName> root CA`, ...). Required by an environment with an xmsg federation node.";
      };
    }
  ];

  den.aspects.applications.dev.ai.mcp.xmsg = {
    settings.genieGuard.ninferUrl = lib.mkOption {
      type = lib.types.strMatching "https?://.+";
      default = "http://10.9.2.2:18020/v1";
      description = "OpenAI-compatible endpoint genie-guard asks for its verdicts (hyperqwen on cortex-cuda).";
    };

    settings.agentQuotaService.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Serve agent-quota on this host's xmsg as `agent-quota@<owner>.<host>`
        (`xmsg service exec`): each request runs `agent-quota --json` and replies with
        its rows. For the system owner only. agent-quota reads no credential file and
        hashes account ids itself (pkgs/by-name/agent-quota).
      '';
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
          };
        }
      );
      default = { };
      description = "Users on this host that run an xmsg federation node, `<user>.<host>`, each with a CA-signed leaf `xmsg-<user>-fed-ca` in the host's secretPath. Declaring one needs `agenix generate`, `git add` of the .age and .crt files, and `agenix rekey`. Its peers and leaves are derived (policies/xmsg.nix).";
    };

    # The fleet observer, PILOT (xmsg-design, owner-approved; Mission Control replaces its
    # login): `xmsg observe-collector` as the user's service on one host, reading the v2
    # observe export of the nodes it lists. Its identity is `<user>.collector`
    # (spiffe://<domain>/host/collector/user/<user>), a leaf from the host intermediate.
    # The view needs an owner bearer even on loopback: the kanidm public client
    # `xmsg-collector` (services/security/kanidm.nix), introspected per request.
    settings.federation.collector = {
      enable = lib.mkEnableOption "the pilot fleet-observer collector for this host's federation user";
      user = lib.mkOption {
        type = lib.types.str;
        default = "sini";
        description = "The user who runs the collector; it needs a node on this host.";
      };
      sources = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "sini.cortex" ];
        description = "Node names the collector polls. Each must grant it (that host's federation.observedBy).";
      };
      subject = lib.mkOption {
        type = lib.types.strMatching "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}";
        description = "The owner's kanidm person UUID, the only `sub` the collector admits.";
      };
      kanidmDomain = lib.mkOption {
        type = lib.types.str;
        example = "idm.example.org";
        description = "kanidm's name, for the issuer and the introspection endpoint.";
      };
    };

    settings.federation.relayedBy = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "sini.cortex" ];
      description = "Hubs (`<user>.<host>`) this host's nodes accept forwarded messages from: their peer entry gets `relayed` (xmsg hubs-and-leaves, forwarding through a hub).";
    };

    settings.federation.observedBy = lib.mkOption {
      type = lib.types.listOf (lib.types.strMatching "[a-z0-9-]+\\.collector");
      default = [ ];
      example = [ "sini.collector" ];
      description = "Collectors (`<user>.collector`) granted `observe` on this host's nodes of the same user (sini.collector observes sini's node, never vic's): node-wide, metadata only, no labels, never send, reply or list.";
    };

    # darwin hosts run their user's node under launchd (the xmsg home-manager module's
    # agent). They take the same secrets; no linger (a launchd agent lives with the
    # login), and no leaf firewall rules (leaf pods hub on the Linux nodes).
    darwin =
      {
        config,
        environment,
        host,
        ...
      }:
      let
        nodes = (fedOf host).nodes;
      in
      lib.mkIf (nodes != { }) {
        assertions = lib.mapAttrsToList (user: _: {
          assertion = config.users.users ? ${user};
          message = "xmsg federation: ${host.name} declares a node for ${user}, who has no account here.";
        }) nodes;
        age.secrets = fedSecrets { inherit config environment host; };
      };

    nixos =
      {
        config,
        environment,
        host,
        k3s-nodes,
        xmsg-leaves,
        ...
      }:
      let
        nodes = (fedOf host).nodes;
        self' = user: nodeName host.name user;
        leavesOf = name: lib.filter (l: lib.elem name l.hubs) xmsg-leaves;
        leafRules = lib.concatStrings (
          lib.concatLists (
            lib.mapAttrsToList (
              user: node:
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
              ) (leavesOf (self' user))
            ) nodes
          )
        );
      in
      {
        # Every xmsg node's federation port on this host, by node name: login users'
        # here, services' (services/matrix-xmsg.nix) and the genie tier buses'
        # (services/ai/genie-xmsg.nix) where they declare theirs.
        options.xmsg.federationPorts = lib.mkOption {
          type = lib.types.attrsOf lib.types.port;
          default = { };
          internal = true;
          description = "Federation port of each xmsg node on this host, by node name.";
        };

        config = lib.mkMerge [
          {
            assertions = [
              {
                assertion = lib.allUnique (lib.attrValues config.xmsg.federationPorts);
                message = "xmsg federation: two nodes on ${host.name} share a port: ${builtins.toJSON config.xmsg.federationPorts}.";
              }
            ];
            xmsg.federationPorts = lib.mapAttrs' (user: n: lib.nameValuePair (self' user) n.port) nodes;
          }
          (lib.mkIf (nodes != { }) {
            # A federated node is the user's xmsg, a user service: it must outlive their logins,
            # or peers lose it whenever the user is logged out. A user's own linger setting wins.
            users.users = lib.mapAttrs (_: _: { linger = lib.mkOverride 900 true; }) nodes;

            assertions = lib.mapAttrsToList (user: _: {
              assertion = config.users.users ? ${user};
              message = "xmsg federation: ${host.name} declares a node for ${user}, who has no account here.";
            }) nodes;

            # No firewall rule for peers: the tailnet interface is trusted
            # (core.network.tailscale), so the ports are reachable over the tailnet and
            # nowhere else, and each CA identity admits only the peers listed.
            age.secrets = fedSecrets { inherit config environment host; };

            # Leaves reach the port over the LAN from their cluster's nodes. The rules are
            # nftables syntax, which the iptables backend ignores, leaving the port closed.
            networking.nftables.enable = lib.mkIf (leafRules != "") true;
            networking.firewall.extraInputRules = lib.mkIf (leafRules != "") leafRules;
          })
        ];
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

    # xmsg.db: registrations, attestation and revocation state.
    persistHome.directories = [ ".local/state/xmsg" ];

    # TRANSITION SHIM (xmsg PR-A, 912ca97a; removed with xmsg-mqsh). xmsg now serves its
    # sockets from a managed namespace <rt>/xmsg-<uid>-<hex>/ instead of <rt>/xmsg/. New
    # clients compute that namespace themselves, but consumers built against the old
    # layout (genie-agent's guard, tier1 and dispatchers; MCP processes started before the
    # switch) look in <rt>/xmsg. The symlink <rt>/xmsg -> the namespace serves both.
    homeLinux =
      { pkgs, ... }:
      let
        shim = legacyShim pkgs ''
          legacy="''${XDG_RUNTIME_DIR:?}/xmsg"; parent="$XDG_RUNTIME_DIR"; export parent
        '';
      in
      {
        systemd.user.services.xmsg.Service.ExecStartPre = [ shim.pre ];
        systemd.user.services.xmsg-legacy-link = {
          Unit = {
            Description = "xmsg legacy socket path <rt>/xmsg -> its managed namespace (transition shim, xmsg-mqsh)";
            After = [ "xmsg.service" ];
            BindsTo = [ "xmsg.service" ];
          };
          Service = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = shim.link;
          };
          Install.WantedBy = [ "xmsg.service" ];
        };
      };

    # darwin: $TMPDIR/xmsg to /tmp/xmsg-<uid>-<hex> (xmsg install_paths), refreshed each
    # minute (launchd has no ExecStartPost; /tmp is cleared at boot).
    homeDarwin =
      { pkgs, ... }:
      let
        shim = legacyShim pkgs ''
          t=$(/usr/bin/getconf DARWIN_USER_TEMP_DIR); legacy="''${t%/}/xmsg"; parent=/private/tmp; export parent
        '';
      in
      {
        launchd.agents.xmsg-legacy-link = {
          enable = true;
          config = {
            ProgramArguments = [ "${shim.link}" ];
            RunAtLoad = true;
            StartInterval = 60;
          };
        };
      };

    homeManager =
      {
        config,
        environment,
        host,
        inputs',
        osConfig,
        pkgs,
        xmsg-leaves,
        xmsg-nodes,
        ...
      }:
      let
        # The host guard serves the @genie bot's host as the standby to the pod guard.
        botEnabled = (host.settings.services.matrix-xmsg.rooms or [ ]) != [ ];
        guardEnabled = botEnabled && config.home.username == host.system-owner;
        # genie-agent's Tier 1 (services/ai/genie-tier1.nix) registers as `genie`, from
        # genie-root's own executable.
        tier1Enabled =
          host.hasAspect den.aspects.services.ai.genie-tier1 && config.home.username == host.system-owner;
        tier1Exe = lib.getExe inputs'.genie-agent.packages.genie-root;
        # The expert tiers' dispatchers (services/ai/genie-experts.nix) register one
        # service each, and their Claude sessions live in per-tier config dirs.
        genie = osConfig.services.genie-agent;
        # Off until the tiers' tokens exist (genie-experts.nix).
        expertsEnabled =
          host.hasAspect den.aspects.services.ai.genie-experts
          && genie.experts.enable
          && config.home.username == host.system-owner;
        expertTiers = [
          genie.experts.public
          genie.experts.trusted
        ];
        guardExe = lib.getExe inputs'.genie-agent.packages.genie-guard;
        # agent-quota@<owner>.<host>: registered by the `xmsg service exec` runner, so
        # the trusted executable is xmsg's own.
        agentQuotaEnabled =
          host.settings.applications.dev.ai.mcp.xmsg.agentQuotaService.enable
          && config.home.username == host.system-owner;

        me = config.home.username;
        node = (fedOf host).nodes.${me} or null;
        rootCa = caCrt (caDir + "/root.crt");
        self' = nodeName host.name me;
        # Each entry trusts the root with the peer's one identity, keyed by the node name
        # that identity derives. A leaf entry's `address` is required but never dialled,
        # since sends to a leaf are queued and replies to it not pushed, so it names a host
        # that cannot resolve. No `from`: the host data carries no tailnet address.
        peers =
          lib.listToAttrs (
            map (
              p:
              lib.nameValuePair p.name {
                inherit (p) address;
                # A service node's record names what it may do here (policies/xmsg.nix); a hub
                # this host trusts to relay to it also gets `relayed`.
                allow =
                  p.allow or [
                    "send"
                    "reply"
                    "list"
                  ]
                  ++ lib.optional (lib.elem p.name (fedOf host).relayedBy) "relayed";
                ca = rootCa;
                identities = [ p.identity ];
              }
            ) (lib.filter (p: p.name != self') xmsg-nodes)
          )
          // lib.listToAttrs (
            map (
              leaf:
              lib.nameValuePair (leafNode leaf) {
                address = "${leafNode leaf}.invalid:${toString node.port}";
                ca = rootCa;
                identities = [ leaf.identity ];
                leaf = true;
                # `forward` only where the leaf record names this node (single-hop relay).
                allow = leaf.allow ++ lib.optional (lib.elem self' (leaf.forwardAt or [ ])) "forward";
                inherit (leaf) targets;
              }
            ) (lib.filter (l: lib.elem self' l.hubs) xmsg-leaves)
          )
          # The pilot collector's grant: observe only, node-wide (targets omitted is this
          # node's own endpoints), no labels. The collector dials; its address is never used.
          // lib.listToAttrs (
            map (
              c:
              lib.nameValuePair c {
                address = "${c}.invalid:${toString node.port}";
                ca = rootCa;
                identities = [ (spiffeOf environment.domain "collector" (lib.removeSuffix ".collector" c)) ];
                allow = [ "observe" ];
              }
              # Only a collector's own user's nodes: another user's node here is not its to observe.
            ) (lib.filter (c: c == "${me}.collector") (lib.optionals (node != null) (fedOf host).observedBy))
          );

        collector = (fedOf host).collector;
        collectorOn = collector.enable && me == collector.user;
        collectorDir = "${config.xdg.configHome}/xmsg/observe-collector";
      in
      {
        # A service node is another user's only through a trusted pair; a record that
        # reached this node by any other path fails the build instead of linking.
        assertions = map (p: {
          assertion = xl.trusts den.users.registry me p.owner;
          message = "xmsg federation: ${self'} would peer ${p.name}, a service of ${p.owner}, who is neither ${me} nor in xmsg.trusts with them.";
        }) (lib.filter (p: p ? owner) xmsg-nodes);

        programs.xmsg = {
          enable = true;
          # Linux runs our own build (pkgs/by-name/xmsg, also the genie tiers' bus); it is
          # Linux-only, so darwin takes the module's default, the input's own package.
          package = lib.mkIf pkgs.stdenv.hostPlatform.isLinux pkgs.local.xmsg;
          server = {
            enable = true;
            # The bot itself registers on its own node (services/matrix-xmsg.nix).
            svcExe =
              lib.optionalAttrs guardEnabled { genie-guard = guardExe; }
              // lib.optionalAttrs agentQuotaEnabled { agent-quota = lib.getExe config.programs.xmsg.package; }
              // lib.optionalAttrs tier1Enabled { genie = tier1Exe; }
              // lib.optionalAttrs expertsEnabled (
                lib.listToAttrs (
                  map (t: lib.nameValuePair t.serviceName (lib.getExe genie.experts.dispatcherPackage)) expertTiers
                )
              );
            extraSessionsDirs = lib.optionals expertsEnabled (
              map (t: "${genie.stateDir}/claude-${t}/sessions") [
                "public"
                "trusted"
              ]
            );
            federation = lib.mkIf (node != null) {
              enable = true;
              inherit (node) port;
              inherit peers;
              cert = caCrt (host.secretPath + "/${leafName me}.crt");
              key = osConfig.age.secrets.${leafName me}.path;
            };
          };
          # The pilot collector (settings.federation.collector), loopback only: no web_tls.
          # Its key and certificate are runtime paths, never store paths (the module asserts
          # it): the key from agenix, the certificate a symlink the user's config owns.
          observeCollector = lib.mkIf collectorOn {
            enable = true;
            config = {
              client_cert = "${collectorDir}/client.crt";
              client_key = osConfig.age.secrets.${collectorLeafName me}.path;
              auth = {
                issuer = "https://${collector.kanidmDomain}/oauth2/openid/xmsg-collector";
                introspection_url = "https://${collector.kanidmDomain}/oauth2/token/introspect";
                subjects = [ collector.subject ];
                audience = "xmsg-collector";
                hosted_client = "xmsg-collector";
              };
              sources = map (
                name:
                let
                  # A node's own record never reaches it (policies/xmsg.nix), so this host's
                  # node is added from its own settings, as xmsg-node emits it.
                  self = {
                    name = self';
                    address = "${host.name}.ts.${environment.domain}:${toString node.port}";
                    identity = spiffeOf environment.domain host.name me;
                  };
                  p =
                    lib.findFirst (n: n.name == name)
                      (throw "xmsg collector: source ${name} is not an xmsg node this user federates with.")
                      ([ self ] ++ xmsg-nodes);
                in
                {
                  node = name;
                  inherit (p) address identity;
                  ca = "${rootCa}";
                }
              ) collector.sources;
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
                "codex"
              ]
              (_: {
                enable = true;
              });
        };

        # The collector's certificate at a runtime path (observeCollector refuses store paths).
        home.file = lib.mkIf collectorOn {
          "${lib.removePrefix "${config.home.homeDirectory}/" collectorDir}/client.crt".source = caCrt (
            host.secretPath + "/${collectorLeafName me}.crt"
          );
        };

        systemd.user.services.agent-quota = lib.mkIf agentQuotaEnabled {
          Unit = {
            Description = "agent-quota over xmsg (xmsg service exec)";
            After = [ "xmsg.service" ];
            Wants = [ "xmsg.service" ];
          };
          Service = {
            ExecStart = lib.escapeShellArgs [
              (lib.getExe config.programs.xmsg.package)
              "service"
              "exec"
              "--name"
              "agent-quota"
              "--"
              (lib.getExe pkgs.local.agent-quota)
              "--json"
            ];
            Restart = "on-failure";
            RestartSec = 10;
            NoNewPrivileges = true;
            UMask = "0077";
          };
          Install.WantedBy = [ "default.target" ];
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
            # Only what an unprivileged user manager applies without a user namespace
            # (seccomp, no_new_privs, umask). The guard spawns nothing, and it is a
            # Node SEA, so no MemoryDenyWriteExecute (V8 JIT).
            NoNewPrivileges = true;
            LockPersonality = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            SystemCallArchitectures = "native";
            # The model over HTTP, xmsg over unix sockets, netlink for getaddrinfo.
            RestrictAddressFamilies = [
              "AF_UNIX"
              "AF_INET"
              "AF_INET6"
              "AF_NETLINK"
            ];
            UMask = "0077";
          };
          Install.WantedBy = [ "default.target" ];
        };
      };
  };
}
