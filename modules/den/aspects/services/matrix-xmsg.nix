# matrix-xmsg (github:sini/matrix-xmsg): the @genie support bot. It answers trusted
# mentions in its rooms by relaying them to an expert agent session over xmsg's
# HTTP bridge on loopback (anonymous sender; a system service cannot attest on
# agent.sock), so it runs on the host that runs xmsg.
#
# Trust follows kanidm: the IdP's `admins` group, routed here as `idm-users`
# (kanidm.nix → collect-idm-users), mapped to MXIDs as matrix/mas.nix maps admins.
#
# The token comes from `agenix generate` (the synapse-bot-token generator
# registers @genie inside the Synapse pod); `matrix-bot-provision` then joins a
# room with it. The service stays off until `rooms` names a room the bot has
# joined.
#
# Its own xmsg node (M28): the bot runs as the system user matrix-xmsg on the node
# `matrix-xmsg.<host>`, federated with the system owner's nodes (policies/xmsg.nix,
# service nodes), so it reaches the experts and tier 1 there and the owner's sessions
# reach it for open_thread. It listens, so a pod guard it screens through can take it
# as a hub (kubernetes/services/ai/genie-guard.nix): its record's `guards` names that
# guard while screening is on, and the node adopts the pod's leaf in turn.
{
  den,
  inputs,
  lib,
  self,
  ...
}:
let
  adminGroup = "admins";
  xl = import ../applications/dev/ai/mcp/_xmsg-lib.nix { inherit lib self; };
  svcUser = "matrix-xmsg";
  stateDirs = [
    {
      directory = "/var/lib/matrix-xmsg";
      mode = "0755";
    }
    {
      directory = "/var/lib/matrix-xmsg-xmsg";
      mode = "0700";
    }
  ];
  # The guard refs the bot actually calls: its one guardRef, while it screens anything.
  guardsOf =
    cfg:
    lib.optional (
      cfg.screenMentions
      || cfg.screenSolicited
      || lib.any (r: r.screenMentions == true) (lib.attrValues cfg.roomRoutes)
    ) cfg.guardRef;
in
{
  flake-file.inputs.matrix-xmsg = {
    url = "github:sini/matrix-xmsg";
    inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  # The bot's node, for the service-node rule and the pod guards it screens through.
  # Its own aspect, included by the host schema so it emits at the host's scope alone:
  # an emit on the bot aspect, a host include, would also run in each user's scope
  # there and reach that user's node with no rule delivering it. Only the
  # service-node rule (policies/xmsg.nix) delivers this record.
  den.aspects.services.matrix-xmsg-node.xmsg-nodes =
    { environment, host, ... }:
    let
      cfg = host.settings.services.matrix-xmsg or { rooms = [ ]; };
    in
    lib.optionals (cfg.rooms != [ ]) [
      {
        name = xl.nodeName host.name svcUser;
        address = "${host.name}.ts.${environment.domain}:${toString cfg.xmsgPort}";
        lanIp = builtins.head host.ipv4;
        port = cfg.xmsgPort;
        identity = xl.spiffeOf host.name svcUser;
        owner = host.system-owner;
        allow = [
          "send"
          "reply"
        ];
        guards = guardsOf cfg;
      }
    ];

  den.schema.host.includes = [ den.aspects.services.matrix-xmsg-node ];

  den.aspects.services.matrix-xmsg = {
    settings = {
      rooms = lib.mkOption {
        type = lib.types.listOf (lib.types.strMatching "![^:]+(:.+)?"); # room v12 IDs have no :server
        default = [ ];
        example = [ "!abcdef:json64.dev" ];
        description = "Room IDs (not aliases) the bot serves. Empty keeps the service disabled; `matrix-bot-provision` prints the value.";
      };
      expertRef = lib.mkOption {
        type = lib.types.str;
        default = "genie-support";
        description = "Label of the xmsg session the bot relays to, on this host's own node: the bot addresses it as `<label>@<user>.<host>`, so an unreachable peer never makes it `unavailable`.";
      };
      roomRoutes = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              expertRef = lib.mkOption {
                type = lib.types.str;
                description = "Label of the xmsg service or session this room relays to, on this host's own node, as for `expertRef`.";
              };
              screenMentions = lib.mkOption {
                type = lib.types.nullOr lib.types.bool;
                default = null;
                description = "Whether the bot screens this room's mentions itself; false for an expert that screens its own input. null keeps the bot's default.";
              };
            };
          }
        );
        default = { };
        example = {
          "!abcdef:json64.dev" = {
            expertRef = "genie";
            screenMentions = false;
          };
        };
        description = "Per-room routing (matrix-xmsg M34) for rooms in `rooms`. Rooms not listed relay to `expertRef`, screened.";
      };
      guardRef = lib.mkOption {
        type = lib.types.str;
        default = "genie-guard@genie-guard.genie";
        description = "xmsg address of the guard the bot screens through. The default is the pod's guard (kubernetes/services/ai/genie-guard.nix), which takes this bot's node as a hub while the bot screens through it.";
      };
      screenMentions = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether the bot screens mentions through `guardRef` (rooms may override it in `roomRoutes`).";
      };
      screenSolicited = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether the bot screens agent-opened threads through `guardRef`.";
      };
      xmsgPort = lib.mkOption {
        type = lib.types.port;
        default = 7791;
        description = "Federation port of the bot's xmsg node, distinct from every other node's on the host.";
      };
      answerTimeoutSecs = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = null;
        description = "Seconds the bot waits for an answer before escalating to the owner. null derives it from this host's genie-agent tier 1 (queue wait + turn deadline + 60 s grace) when it runs one, else keeps the module's default.";
      };
      extraTrustedMxids = lib.mkOption {
        type = lib.types.listOf (lib.types.strMatching "@[^:]+:.+");
        default = [ ];
        example = [ "@alice:matrix.org" ];
        description = "Trusted senders beyond kanidm `admins`: accounts on other homeservers, which kanidm cannot list.";
      };
    };

    nixos =
      {
        config,
        environment,
        host,
        idm-users,
        inputs',
        k3s-nodes,
        pkgs,
        xmsg-leaves,
        xmsg-nodes,
        ...
      }:
      let
        cfg = host.settings.services.matrix-xmsg;
        self' = xl.nodeName host.name svcUser;
        owner = xl.nodeName host.name host.system-owner;
        mxid = name: "@${name}:${environment.domain}";
        # The environment whose kanidm serves this host's (dev delegates to prod).
        idpEnv = (environment.services.kanidm or { }).delegateTo or null;
        trusted = lib.sort lib.lessThan (
          lib.unique (
            cfg.extraTrustedMxids
            ++ map (u: mxid u.name) (
              lib.filter (
                u:
                u.environment == (if idpEnv != null then idpEnv else environment.name)
                && lib.elem adminGroup u.groups
              ) idm-users
            )
          )
        );
        rootCa = xl.caCrt (xl.caDir + "/root.crt");
        # The system owner's nodes (policies/xmsg.nix collects them here).
        ownerNodes = lib.filter (n: n.name != self' && !(n ? guards)) xmsg-nodes;
        # The pod leaves this bot screens through, by the node part of each guard ref.
        guardNodes = map (g: lib.last (lib.splitString "@" g)) (guardsOf cfg);
        leafNodeOf =
          leaf:
          let
            m = builtins.match "spiffe://[^/]+/ns/([^/]+)/sa/([^/]+)" leaf.identity;
          in
          "${lib.elemAt m 1}.${lib.elemAt m 0}";
        leaves = lib.filter (l: lib.elem (leafNodeOf l) guardNodes) xmsg-leaves;
        leafRules = lib.concatMapStrings (
          leaf:
          lib.concatMapStrings
            (n: ''
              ip saddr ${n.ip} tcp dport ${toString cfg.xmsgPort} accept comment "xmsg leaf ${leafNodeOf leaf} of ${self'}: ${n.hostname}"
            '')
            (lib.sort (a: b: a.hostname < b.hostname) (lib.filter (n: n.clusterName == leaf.cluster) k3s-nodes))
        ) leaves;
        leafSecretName = xl.leafName svcUser;
        # A tier-1 answer can take its queue wait plus its turn deadline; waiting less
        # sends the owner a false timeout DM.
        genie = config.services.genie-agent or { enable = false; };
        # shortcut: 600 s restates genie-agent's QUESTION_TIMEOUT_MS default, read it from the module if it ever exposes one.
        tier1AnswerSecs =
          genie.tier1.maxQueueWaitSecs
          + (if genie.tier1.questionTimeoutMs != null then genie.tier1.questionTimeoutMs / 1000 else 600)
          + 60;
        answerTimeoutSecs =
          if cfg.answerTimeoutSecs != null then
            cfg.answerTimeoutSecs
          else if genie.enable then
            tier1AnswerSecs
          else
            null;
      in
      {
        imports = [ inputs.matrix-xmsg.nixosModules.default ];

        warnings = lib.optional (cfg.rooms == [ ]) ''
          matrix-xmsg: settings.services.matrix-xmsg.rooms is empty on ${host.name}, so the @genie bot is NOT enabled.
          Run `agenix generate` (once, for the token), then `matrix-bot-provision '#support:${environment.domain}'` and set the room ID it prints.
        '';

        # Declared before any room is set: the token must exist to join one.
        age.secrets.matrix-genie-token = {
          rekeyFile = host.secretPath + "/matrix-genie-token.age";
          generator.script = "synapse-bot-token";
          settings = {
            namespace = "matrix";
            workload = "deploy/synapse";
            user = "genie";
            secretsFile = "/secrets/secrets.yaml";
          };
        };

        # E2EE (matrix-xmsg M36): the crypto store's passphrase, the running bot's
        # credential; and the recovery key, which unlocks the cross-signing keys in
        # secret storage and the room-key backup, read only by the one-shot
        # matrix-xmsg-e2ee-setup unit. Both are read by systemd (LoadCredential).
        age.secrets.matrix-xmsg-store-key = lib.mkIf (cfg.rooms != [ ]) {
          rekeyFile = host.secretPath + "/matrix-xmsg-store-key.age";
          generator.script = "rfc3986-secret";
        };
        age.secrets.matrix-xmsg-recovery-key = lib.mkIf (cfg.rooms != [ ]) {
          rekeyFile = host.secretPath + "/matrix-xmsg-recovery-key.age";
          generator.script = "rfc3986-secret";
        };

        age.secrets.${leafSecretName} = lib.mkIf (cfg.rooms != [ ]) (
          xl.leafSecret {
            inherit config host;
            user = svcUser;
          }
        );

        xmsg.federationPorts = lib.mkIf (cfg.rooms != [ ]) { ${self'} = cfg.xmsgPort; };

        # The pod leaves' cluster nodes, on this node's port only. Peers come over the
        # tailnet, which is trusted (core.network.tailscale), or loopback.
        networking.nftables.enable = lib.mkIf (leafRules != "") true;
        networking.firewall.extraInputRules = lib.mkIf (leafRules != "") leafRules;

        services.matrix-xmsg = lib.mkIf (cfg.rooms != [ ]) {
          enable = true;
          package = inputs'.matrix-xmsg.packages.default;
          homeserverUrl = "https://${environment.getDomainFor "matrix"}";
          botMxid = mxid "genie";
          ownerMxid = mxid "json";
          accessTokenFile = config.age.secrets.matrix-genie-token.path;
          storePassphraseFile = config.age.secrets.matrix-xmsg-store-key.path;
          recoveryKeyFile = config.age.secrets.matrix-xmsg-recovery-key.path;
          # The system user matrix-xmsg, on its own node; xmsgSocket is the module's
          # default, that node's socket dir.
          dynamicUser = false;
          user = svcUser;
          trustedMxids = trusted;
          inherit (cfg)
            rooms
            guardRef
            screenMentions
            screenSolicited
            ;
          # Both refs carry the owner's node name (xmsg README 7.0), so an expert of the
          # same name elsewhere in view never makes them ambiguous.
          expertRef = "${cfg.expertRef}@${owner}";
          roomRoutes = lib.mapAttrs (
            _: r:
            {
              expertRef = "${r.expertRef}@${owner}";
            }
            // lib.optionalAttrs (r.screenMentions != null) { inherit (r) screenMentions; }
          ) cfg.roomRoutes;
          openThreadNodes = map (n: n.name) ownerNodes;
          answerTimeoutSecs = lib.mkIf (answerTimeoutSecs != null) answerTimeoutSecs;

          xmsg = {
            enable = true;
            package = pkgs.local.xmsg;
            federation = {
              enable = true;
              # Peers reach it by its tailnet name, and same-host ones over loopback,
              # so it binds every address; the firewall admits the pods' nodes only.
              listenAddress = "0.0.0.0";
              port = cfg.xmsgPort;
              cert = xl.caCrt (host.secretPath + "/${leafSecretName}.crt");
              key = config.age.secrets.${leafSecretName}.path;
              peers =
                lib.listToAttrs (
                  map (
                    n:
                    lib.nameValuePair n.name (
                      xl.caPeer rootCa [
                        "send"
                        "reply"
                        "list"
                      ] n
                    )
                  ) ownerNodes
                )
                // lib.listToAttrs (
                  map (
                    leaf:
                    lib.nameValuePair (leafNodeOf leaf) {
                      address = "${leafNodeOf leaf}.invalid:${toString cfg.xmsgPort}";
                      ca = rootCa;
                      identities = [ leaf.identity ];
                      leaf = true;
                      inherit (leaf) allow targets;
                    }
                  ) leaves
                );
            };
          };
        };
      };

    persist =
      { host, ... }:
      lib.optionalAttrs ((host.settings.services.matrix-xmsg.rooms or [ ]) != [ ]) {
        directories = map (
          d:
          d
          // {
            user = svcUser;
            group = svcUser;
          }
        ) stateDirs;
      };
  };
}
