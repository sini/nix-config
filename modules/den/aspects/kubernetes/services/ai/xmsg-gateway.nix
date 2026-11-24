# xmsg-mcp-gateway as a pod (github:sini/xmsg-mcp-gateway, xmsg-design's gateway
# edge-alignment amendment §2.1–2.4): an OAuth-protected MCP endpoint whose messaging
# node is an xmsg leaf in the same pod, the genie-guard.nix pattern. The leaf's hubs are
# the system owner's xmsg on the `hub` host and on each `extraHubs` host; senders there
# address the gateway as `xmsg-gateway@xmsg-gateway.xmsg-gateway`, each hub queues those
# sends in the leaf's mailbox, and the gateway commits them to custody and wakes the
# owner's ChatGPT subscription (MCP Events). The gateway sends and replies through the
# leaf's agent.sock. A leaf reaches only the nodes in its peers file, and a node delivers
# only to its own sessions, so every node whose sessions the gateway addresses is a hub.
#
# Two inbound paths. MCP: the tunnel-client sidecar (settings.tunnel) on loopback.
# OAuth discovery and the gateway's authorization server: public HTTPS through
# envoy-gateway, on an HTTPRoute that carries only those paths (everything else,
# /mcp included, 404s at the edge). The listener binds the pod network for envoy
# (allow_non_loopback_bind, serving.md "Exposure and request protection"), and a
# CiliumNetworkPolicy admits only the gateways namespace to it.
#
# One uid on every container: the leaf admits register.sock and agent.sock callers by
# SO_PEERCRED uid, and the gateway's messaging.xmsg.daemon_uid must equal the leaf's.
# 10001 is the gateway image's own user.
#
# The gateway refuses group- or world-accessible credential files and a state
# directory others can write, and its Events key must be exactly 0600 and owned by
# the owner of its directory. Kubernetes Secret files are root-owned, so the chart's
# `prepare` initContainer (busybox, as this uid) copies the secrets into a memory
# emptyDir directory it owns (lookup secret 0400, Events key 0600), and makes the PVC's
# state directories 0700. The PVC keeps fsGroupChangePolicy OnRootMismatch, so kubelet
# never re-adds group write to them on a later mount. The gateway itself refuses an
# Events key that is not 32 bytes (event_store.rs), at the first migrate-events.
#
# Grant store (events.md "Configure and migrate", serving.md "Repeatable migrations in a
# shell-less init chain"). Initialization never overwrites, so the real store is
# created only when absent. The gateway image has no shell, so the fresh path always
# builds a store in a staging directory on the PVC (init, every migration, enroll: a
# new grant is enrolled after migrate-events, so its never-enabled history is
# explicit), and `store-install` (busybox) moves it into place only if state/grants.db
# is absent. Otherwise it discards it. A crash between steps therefore never leaves a
# half-built real store. A new grant is disabled at revision 1: `enable` is never run
# here. It is a deliberate one-time cutover step
# (`xmsg-mcp-gateway --state /var/lib/xmsg-mcp-gateway/state/grants.db enable chatgpt 1`).
#
# Migrations: every migrate-* runs with --if-needed, on the staged store and then on
# the real one, in the gateway's order. --if-needed migrates a store that needs it and
# otherwise prints `already migrated` and exits 0 without writing; unknown markers,
# unsupported schemas and partial migrations still fail (serving.md). Retirement and
# custody summaries are one-way (older images refuse their application_id), so
# `store-backup` (the pinned python image, for its sqlite3 module) first asks the
# gateway itself: it runs the gateway's `migrations-pending` on the real store (serving.md
# "Inspect pending migrations": one read-only snapshot, exit 0 none pending, 10 pending,
# 1 a missing, corrupt or unsupported store). The gateway binary comes from an image
# volume of the gateway image (its /nix at /nix, so the binary's own loader resolves,
# and its /bin), because a nonzero exit fails an initContainer: a gateway-image step
# could not report exit 10 and let the chain go on. Only on exit 10 does it take an
# online backup (the sqlite3 backup API, never cp) to
# backups/grants.db.pre-migrate-<UTC time>; on 0, a fresh store included, none. Any
# other exit fails the pod. Rolling back to an older image means restoring that backup.
#
# Outbound policy (outbound.md, `apply`): `store-apply`, the last step, then applies
# policy.json, the grant's send and reply targets (every hub's sessions), to the real
# store. apply compares policies as typed values and an unchanged one prints `unchanged
# at revision N`, writes nothing and exits 0, so a restart is a no-op. A change advances
# the revision by one (and, like set-outbound-policy, pauses the Events subscription).
# No --enabled or --disabled: apply keeps the grant's enablement. The grant always
# exists here (store-install leaves an enrolled store), and a missing one fails the pod.
#
# Backup: the Events key encrypts the store's callback URLs, delivery secrets and
# retained tokens, so the store is useless without it. The key lives in agenix (git)
# and the PVC joins Longhorn's nightly off-cluster backup group (media-config). Restore
# both together.
#
# The pod is the gateway's own chart (charts/xmsg-mcp-gateway, the
# `xmsg-mcp-gateway-chart` input): it owns the hardening, the shared uid, the in-pod
# paths and serving.json's pod-owned fields, `prepare`, the real store's migrations and
# applies, the leaf, the tunnel sidecar, the Service, the routes, the PVC and the custody
# alerts. This aspect sets only the instance. fullnameOverride and serviceAccount.name
# keep every object named xmsg-gateway (the SA the SPIFFE id names).
#
# shortcut: the staged-store chain (staging, staged-*, store-install, store-backup) rides
# in the chart's store.preMigrate slot because the pinned gateway image predates `init
# --if-needed`, `enroll --if-needed` and `backup-if-pending`; drop it for
# store.bootstrap.enabled and a backup-if-pending hook once the image is at or past the
# chart's rev. Transition shim, removed by bead xmsg-1as8 (check hot-journal recovery first).
#
# Gating check: xmsg-gateway-check.nix, over axon's rendered manifests.
{
  den,
  lib,
  inputs,
  rootPath,
  ...
}:
let
  namespace = "xmsg-gateway";
  name = "xmsg-gateway";
  # The xmsg service the gateway registers, which is also its grant service.
  service = name;
  # The leaf's node name, from its URI SAN (`<sa>.<ns>`).
  node = "${name}.${namespace}";
  grantId = "chatgpt";
  # The gateway authorization server's grant and its pre-registered hosted client
  # (xmsg-design gateway-authorization-server.md §2.8, §2.10; owner 2026-11-18).
  localGrantId = "chatgpt-as";
  asClient = "xmsg-chatgpt";
  # Kanidm's public PKCE client for the AS's upstream login (services/security/kanidm.nix).
  loginClient = "xmsg-gateway-login";
  # The dedicated hosted client (services/security/kanidm.nix), and its lookup twin.
  hostedClient = "xmsg-gateway";
  lookupClient = "xmsg-gateway-lookup";
  uid = 10001;
  issuer = "xmsg-cluster-ca";
  port = 8787;

  # The in-pod paths are the chart's (_helpers.tpl); these name the ones the instance
  # values and the staged chain refer to.
  tlsDir = "/etc/xmsg/tls";
  configDir = "/etc/xmsg-mcp-gateway";
  dataDir = "/var/lib/xmsg-mcp-gateway";
  stateDir = "${dataDir}/state";
  stagingDir = "${dataDir}/staging";
  # The chart's `prepare` copies each secrets item to <keysDir>/<item key>.
  keysDir = "/run/xmsg-mcp-gateway/keys";
  grantStore = "${stateDir}/grants.db";
  stagedStore = "${stagingDir}/grants.db";
  backupsDir = "${dataDir}/backups";
  # store-backup keeps this many pre-migrate copies (xmsg-design, 2026-11-13).
  keepPreMigrate = 3;
  # The gateway image's /bin, mounted in store-backup (its symlink resolves into /nix).
  gatewayBinDir = "/opt/xmsg-mcp-gateway/bin";
  gatewayBin = "${gatewayBinDir}/xmsg-mcp-gateway";
  eventsKey = "${keysDir}/events-key";
  lookupSecret = "${keysDir}/lookup-secret";
  asClientSecret = "${keysDir}/as-client-secret";
  livenessToken = "${keysDir}/liveness-token";

  # Budgets (serving.md, events.md). The store's busy wait is the gateway's own 30 s
  # (grants.rs Store::open).
  timeouts = {
    verifier = 5000;
    storeWait = 30000;
    submission = 20000;
    dispatch = 16000;
    request = 60000;
    # The gateway's default, explicit so the chart's attachment budget rule checks it
    # (serving.md: attachment tools refuse <= 11000, the daemon's 10 s pending wait).
    operation = 15000;
  };

  # Enabled, and refused by name until a tunnel image is pinned.
  enabledFor =
    cluster: images:
    let
      cfg = cluster.settings.kubernetes.services.ai.xmsg-gateway;
    in
    if cfg.enable && cfg.tunnel.enable && !(images ? "openai/tunnel-client") then
      throw ''
        xmsg-gateway: tunnel.enable needs images/openai/tunnel-client/default.nix. Run
        `nix run .#oci-image-updater -- init --image-name ghcr.io/openai/tunnel-client --image-tag v0.0.20 --arch amd64 --os linux`
        and move the file to images/openai/tunnel-client/.
      ''
    else if cfg.enable && cfg.tunnel.enable && cfg.tunnel.id == null then
      throw "xmsg-gateway: tunnel.enable needs tunnel.id, the Platform tunnel's id (tunnel_...)."
    else
      cfg.enable;

  # spiffe trust domains: a host's and the cluster's own are their environments' domains.
  domainOf = entity: den.environments.${entity.environment}.domain;

  # A required host-name setting, refused by name while unset.
  hostSetting =
    cfg: key:
    if cfg.${key} == null then
      throw "xmsg-gateway: enable needs settings.kubernetes.services.ai.xmsg-gateway.${key}."
    else
      cfg.${key};

  ref = image: "${image.repository}@${image.digest}";

  hardened = {
    runAsUser = uid;
    runAsGroup = uid;
    runAsNonRoot = true;
    readOnlyRootFilesystem = true;
    allowPrivilegeEscalation = false;
    capabilities.drop = [ "ALL" ];
  };
in
{
  # Source-only pin of the chart, apart from the image pin the pod runs.
  flake-file.inputs.xmsg-mcp-gateway-chart = {
    url = "github:sini/xmsg-mcp-gateway/56861f16c3b4ef8891954a45b6b8bc1258d2ca24";
    flake = false;
  };

  den.aspects.kubernetes.services.ai.xmsg-gateway = {
    # The public name the HTTPRoute serves (kanidm.nix's xmsgGateway.origin default).
    served-domains =
      { cluster, ... }:
      cluster.servedDomains (
        lib.optional cluster.settings.kubernetes.services.ai.xmsg-gateway.enable "xmsg-gateway"
      );

    settings = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Run xmsg-mcp-gateway with its xmsg leaf as a pod in the xmsg-gateway namespace. Needs images/sini/xmsg-mcp-gateway and the xmsg-cluster-ca issuer.";
      };

      hub = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "cortex";
        description = "The host whose owner's xmsg is the leaf's hub. That node takes the leaf from the xmsg-leaves record this aspect emits. Required with enable.";
      };

      extraHubs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "bitstream" ];
        description = "More hosts whose owner's xmsg is also the leaf's hub, so the gateway reaches and lists their sessions too. Each takes the leaf from the same xmsg-leaves record.";
      };

      relayed = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "sini.patch" ];
        description = "Nodes (`<user>.<host>`) the gateway reaches through its `hub` by single-hop forwarding (xmsg hubs-and-leaves, forwarding through a hub), never as its own peers: the hub grants the leaf `forward`, the leaf routes unknown destinations to the hub (`default_route`), and the grant's outbound policy admits them. Each must grant the hub `relayed` (that host's federation.relayedBy).";
      };

      kanidmHost = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "uplink";
        description = "The host running kanidm: its xmsgGateway.origin gives the gateway's resource, and its address is the pinned introspection connection. Required with enable.";
      };

      subject = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.strMatching "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
        );
        default = null;
        description = ''
          The owner's `sub` as kanidm introspection reports it: the person's UUID (kanidm
          idm/oauth2.rs sets `sub` to the account UUID). Measure it from one real token;
          never guess it. While null the Deployment is withheld (a warning says so), so
          no grant is ever enrolled under a wrong subject; everything else renders.
        '';
      };

      authorizationServer.redirectUris = lib.mkOption {
        type = lib.types.nullOr (lib.types.nonEmptyListOf lib.types.str);
        default = null;
        example = [ "https://chatgpt.com/connector/oauth/<id>" ];
        description = ''
          The exact per-connector redirect URIs of the hosted client the gateway's own
          authorization server serves (`authorization_server.client.redirect_uris`),
          copied from the new connector as ChatGPT shows them. null keeps the gateway
          on the single Kanidm verifier. Set, it serves both profiles: Kanidm hidden
          (advertised false) and the local AS as opaque_default, with Events still on
          the old grant (cutover §2.10 step 3). The local grant must already be
          enrolled and enabled in the store: that is the maintenance window's step.
        '';
      };

      authorizationServer.eventsOnLocalGrant = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Move Events to the local grant (`events.grant_id` = the AS's grant), cutover
          §2.10 step 6. Set only after `cutover-events --from <old> --to <local>` has
          committed its marker: startup refuses an `events.grant_id` other than the
          latest marker's `to_grant`. Requires the authorization server.
        '';
      };

      tunnel = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Run the OpenAI tunnel-client as a sidecar on the gateway's loopback listener. Off until cutover: the sidecar is then omitted entirely.";
        };
        id = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "tunnel_0123456789abcdef0123456789abcdef";
          description = "The Platform tunnel id the sidecar serves. Required with tunnel.enable.";
        };
      };
    };

    # The hub takes the leaf from this record (applications/dev/ai/mcp/xmsg.nix).
    xmsg-leaves =
      { cluster, ... }:
      let
        cfg = cluster.settings.kubernetes.services.ai.xmsg-gateway;
      in
      lib.optionals cfg.enable [
        {
          identity = "spiffe://${domainOf cluster}/ns/${namespace}/sa/${name}";
          cluster = cluster.name;
          hubs = map (h: "${den.hosts.x86_64-linux.${h}.system-owner}.${h}") (
            [ (hostSetting cfg "hub") ] ++ cfg.extraHubs
          );
          # It sends and replies to the hubs' sessions and lists them; inbound sends
          # need no right.
          allow = [
            "send"
            "reply"
            "list"
          ];
          # `forward` at the primary hub only, for the `relayed` nodes (mcp/xmsg.nix adds it).
          forwardAt = lib.optionals ((cfg.relayed or [ ]) != [ ]) [
            "${den.hosts.x86_64-linux.${hostSetting cfg "hub"}.system-owner}.${hostSetting cfg "hub"}"
          ];
          # Explicitly every target. One `targets` list gates both what the hub queues
          # to the leaf and what the leaf may reach on the hub. The hub's agent sessions
          # are instance ids, which no fixed list can name, so a list would refuse every
          # send to them. Inbound, the leaf hosts the one principal and refuses any
          # other name. The gateway's per-grant outbound policy (policy.json, applied at
          # start) is what narrows its sends.
          targets = null;
        }
      ];

    # Declared with the flag off too, so the sops store holds every value before the
    # pod needs it.
    age-secrets =
      { environment, ... }:
      {
        age.secrets = {
          # 32 random bytes, base64 (the `base64` generator's default length). It must
          # be backed up with the store on the PVC: see the header.
          xmsg-gateway-events-key = {
            rekeyFile = environment.secretPath + "/xmsg-gateway/events-key.age";
            generator.script = "base64";
            sopsOutput = {
              file = "xmsg-gateway";
              key = "events-key";
            };
          };
          # Shared with the kanidm client (services/security/kanidm.nix): same
          # rekeyFile and generator, so one value backs both sides.
          xmsg-gateway-lookup-oidc-client-secret = {
            rekeyFile = environment.secretPath + "/oidc/${lookupClient}-oidc-client-secret.age";
            generator = {
              tags = [ "oidc" ];
              script = "rfc3986-secret";
            };
            sopsOutput = {
              file = "oidc";
              key = lookupClient;
            };
          };
          # The downstream client's secret (`authorization_server.client.secret_file`).
          # The owner enters the same value in the new ChatGPT connector.
          xmsg-gateway-as-client-secret = {
            rekeyFile = environment.secretPath + "/xmsg-gateway/as-client-secret.age";
            generator.script = "oauth-client-secret";
            sopsOutput = {
              file = "xmsg-gateway";
              key = "as-client-secret";
            };
          };
          # The liveness reader's Kanidm API token: a placed secret, minted by the
          # writer's kanidm-xmsg-gateway-liveness (services/security/kanidm.nix) and copied
          # here once, so the gateway's copy doesn't depend on that host's state directory.
          xmsg-gateway-liveness-token = {
            rekeyFile = environment.secretPath + "/xmsg-gateway/liveness-token.age";
            sopsOutput = {
              file = "xmsg-gateway";
              key = "liveness-token";
            };
          };
          # The runtime key cortex's tunnel-client uses (services/ai/openai-tunnel.nix):
          # a placed secret, one value, so no generator here.
          xmsg-gateway-tunnel-runtime-key = {
            rekeyFile = rootPath + "/.secrets/env/dev/openai/tunnel-runtime-key.age";
            sopsOutput = {
              file = "xmsg-gateway";
              key = "tunnel-runtime-key";
            };
          };
        };
      };

    k8s-manifests =
      {
        config,
        cluster,
        images,
        ...
      }:
      let
        cfg = cluster.settings.kubernetes.services.ai.xmsg-gateway;
        # The leaf pulls from every peer in its file, each mailbox on its own.
        hubs = map (h: rec {
          host = den.hosts.x86_64-linux.${h};
          name = "${host.system-owner}.${h}";
          identity = "spiffe://${domainOf host}/host/${h}/user/${host.system-owner}";
          ip = lib.head host.ipv4;
          port = host.settings.applications.dev.ai.mcp.xmsg.federation.nodes.${host.system-owner}.port;
        }) ([ (hostSetting cfg "hub") ] ++ cfg.extraHubs);
        kanidmHost = den.hosts.x86_64-linux.${hostSetting cfg "kanidmHost"};
        # kanidm is reached through the cluster gateway, which fails over between its
        # replicas (services/security/kanidm-ingress.nix); the pin is the gateway VIP,
        # the same address in-cluster DNS answers for kanidm's name.
        kanidmIp = cluster.networks.kubernetes-loadbalancers.assignments.default-gateway;
        kanidmDomain = cluster.domainFor "kanidm";
        # kanidm.nix's own fallback: the kanidm host's environment domain for the gateway.
        origin =
          let
            own = kanidmHost.settings.services.security.kanidm.xmsgGateway.origin;
          in
          if own != null then
            own
          else
            "https://${den.environments.${kanidmHost.environment}.getDomainFor "xmsg-gateway"}";
        resource = "${origin}/mcp";
        verifierIssuer = "https://${kanidmDomain}/oauth2/openid/${hostedClient}";

        primary = lib.head hubs;
        peers = lib.listToAttrs (
          map (h: {
            inherit (h) name;
            value =
              # The relayed nodes aren't peers: unknown explicit destinations go to the
              # primary hub, which forwards them (one hop).
              lib.optionalAttrs ((cfg.relayed or [ ]) != [ ] && h.name == primary.name) { default_route = true; }
              // {
                address = "${h.ip}:${toString h.port}";
                ca = "${tlsDir}/ca.crt";
                identities = [ h.identity ];
                # What the hub may ask of the leaf. `list` lets it answer the hub's list
                # query from its mailbox, so the hub's sessions see the gateway (xmsg XA6).
                # `send` and `reply` gate only fed requests, which a leaf never listens for
                # (xmsg refuses --leaf with --fed-listen); a pulled send reaches only the
                # leaf principal.
                allow = [
                  "send"
                  "reply"
                  "list"
                ];
              };
          }) hubs
        );

        # The grant's outbound policy: each hub's sessions, for send and for reply. The
        # chart writes it as JSON (keys sorted); apply compares typed values.
        permission = scope: {
          targets = map (h: "*@${h.name}") hubs ++ map (n: "*@${n}") (cfg.relayed or [ ]);
          required_scope = scope;
        };
        policy = {
          send = permission "xmsg:send";
          reply = permission "xmsg:reply";
        };

        # The exact enrollment document; the verifier's values below are the same.
        binding = {
          inherit service resource;
          issuer = verifierIssuer;
          subject = cfg.subject;
          hosted_client = hostedClient;
        };

        # The gateway's own authorization server (cutover §2.10 step 3), on when the new
        # connector's redirect URIs are set: both profiles, Kanidm hidden.
        asRedirectUris = (cfg.authorizationServer or { }).redirectUris or null;
        asEnabled = asRedirectUris != null;
        eventsGrant =
          if (cfg.authorizationServer or { }).eventsOnLocalGrant or false then
            assert lib.assertMsg asEnabled
              "xmsg-gateway: authorizationServer.eventsOnLocalGrant needs authorizationServer.redirectUris";
            localGrantId
          else
            grantId;
        # The local grant's enrollment document. The AS issuer is the gateway's public
        # origin, distinct from the resource <origin>/mcp (§2.8 `issuer != R`).
        localBinding = {
          inherit service resource;
          issuer = origin;
          subject = cfg.subject;
          hosted_client = asClient;
        };
        requiredScopes = [
          "identity:read"
          "events:subscribe"
          "xmsg:send"
          "xmsg:reply"
        ];
        kanidmVerifier = {
          inherit service resource;
          inherit (binding) issuer subject hosted_client;
          # Kanidm sets aud to the client name (provider-setup.md "Direct Kanidm").
          audience = hostedClient;
          introspection_url = "https://${kanidmDomain}/oauth2/token/introspect";
          introspection_client = lookupClient;
          client_secret_file = lookupSecret;
          # The gateway VIP, which in-cluster DNS also answers for kanidm's name; the
          # pin needs no DNS.
          provider_addresses = [ kanidmIp ];
          required_scopes = requiredScopes;
          timeout_ms = timeouts.verifier;
        };
        authorizationServer = {
          issuer = origin;
          client = {
            id = asClient;
            secret_file = asClientSecret;
            redirect_uris = asRedirectUris;
          };
          upstream = {
            authorization_endpoint = "https://${kanidmDomain}/ui/oauth2";
            token_endpoint = "https://${kanidmDomain}/oauth2/token";
            client_id = loginClient;
            redirect_uri = "${origin}/oauth/callback";
            # The upstream login token, introspected like the hosted one: the lookup
            # client, the same pin, the owner's subject, scope openid only.
            verify = kanidmVerifier // {
              issuer = "https://${kanidmDomain}/oauth2/openid/${loginClient}";
              audience = loginClient;
              hosted_client = loginClient;
              required_scopes = [ "openid" ];
            };
          };
          liveness = {
            api_url = "https://${kanidmDomain}";
            person = cfg.subject;
            # memberof's SPN shape (kanidm idm/oauth2.rs, the `groups` claim).
            group = "${loginClient}.access@${den.environments.${kanidmHost.environment}.domain}";
            canary_person = "xmsg-gateway-liveness-test";
            token_file = livenessToken;
          };
        };

        # serving.json without the chart's pod-owned fields (bind, allow_non_loopback_bind,
        # grant_store, messaging.xmsg's service/uid/sockets, messaging.manifest), which it
        # writes over these; the chart also refuses the gateway's budget rules at render.
        serving = {
          request_timeout_ms = timeouts.request;
          allowed_hosts = [
            "127.0.0.1"
            "localhost"
            (lib.removePrefix "https://" origin)
          ];
          allowed_origins = [ ];
          messaging = {
            xmsg = {
              expected_node = node;
              operation_timeout_ms = timeouts.operation;
            };
            submission_timeout_ms = timeouts.submission;
            max_reservations = 1000;
            max_retained_bytes = 67108864;
          };
          # Events moves to the local grant only after cutover-events (§2.10 steps
          # 5-6); until then it stays on the OLD grant.
          events = {
            key_file = eventsKey;
            grant_id = eventsGrant;
            dispatch_timeout_ms = timeouts.dispatch;
            # Custody admission counts every row, expired tombstones and other grants'
            # rows included, and a row holds its slot for content + metadata retention
            # (7 + 7 days). At the default 1000 rows that filled on 2026-11-22: every new
            # message was deferred silently, the leaf never acked, and Artemis's inbound
            # wedged (xmsg-lxd2). Sized for ~20x the measured volume (1000 rows, 1.87 MB
            # over 14 days), within the 1Gi data volume. All seven fields are required.
            custody_limits = {
              max_items = 20000;
              max_bytes = 128 * 1024 * 1024;
              max_item_bytes = 256 * 1024;
              content_retention_secs = 604800;
              max_metadata = 1000;
              metadata_retention_secs = 604800;
              max_gap_intervals = 1000;
            };
          };
        }
        // (
          if asEnabled then
            {
              verifier_profiles = [
                (
                  kanidmVerifier
                  // {
                    advertised = false;
                    opaque_default = false;
                  }
                )
                (
                  localBinding
                  // {
                    local = true;
                    opaque_default = true;
                    advertised = true;
                    required_scopes = requiredScopes;
                  }
                )
              ];
              authorization_server = authorizationServer;
            }
          else
            { verifier = kanidmVerifier; }
        );

        mount = vol: path: {
          name = vol;
          mountPath = path;
        };
        roMount = vol: path: mount vol path // { readOnly = true; };
        dataMount = mount "data" dataDir;

        gatewayImage = ref images."sini/xmsg-mcp-gateway";
        image = i: { inherit (images.${i}) repository digest; };
        # The chart's selector labels (_helpers.tpl gw.selectorLabels), for the policies.
        selectorLabels = {
          "app.kubernetes.io/name" = "xmsg-mcp-gateway";
          "app.kubernetes.io/instance" = name;
        };

        # Each store step is the gateway CLI itself: `prefix` names the store it runs on.
        storeStep = prefix: store: args: {
          name = "${prefix}-${lib.head args}";
          image = gatewayImage;
          args = [
            "--state"
            store
          ]
          ++ args;
          securityContext = hardened;
          volumeMounts = [
            dataMount
            (roMount "keys" (dirOf keysDir))
            (roMount "config" configDir)
          ];
        };

        # The gateway's migrations, in its order, each a no-op on a store that has it
        # (the same list the chart runs on the real store).
        migrations =
          prefix: store:
          map (args: storeStep prefix store (args ++ [ "--if-needed" ])) (
            [
              [ "migrate-custody" ]
              [ "migrate-outbound" ]
              [ "migrate-retirement" ]
              [ "migrate-custody-summaries" ]
              [
                "migrate-events"
                "--key-file"
                eventsKey
              ]
              [ "migrate-profiles" ]
              [ "migrate-attachments" ]
            ]
            ++ lib.optional asEnabled [ "migrate-authorization-server" ]
          );

        # The grants the chart applies policy.json to (and whose binding-<id>.json it
        # writes), the first and, with the AS, the local one.
        grants = [
          {
            id = grantId;
            inherit binding policy;
          }
        ]
        ++ lib.optional asEnabled {
          id = localGrantId;
          binding = localBinding;
          inherit policy;
        };

        # store.preMigrate: the staged fresh store, kept only if the real one is absent,
        # then the backup decision; see the header.
        stagedChain = [
          {
            name = "staging";
            image = ref images."library/busybox";
            command = [
              "/bin/sh"
              "-c"
              ''
                set -eu
                umask 077
                rm -rf ${stagingDir}
                mkdir ${stagingDir}
              ''
            ];
            securityContext = hardened;
            volumeMounts = [ dataMount ];
          }
          (storeStep "staged" stagedStore [ "init" ])
        ]
        ++ migrations "staged" stagedStore
        ++ map (
          g:
          storeStep (if g.id == grantId then "staged" else "staged-local") stagedStore [
            "enroll"
            g.id
            "${configDir}/binding-${g.id}.json"
          ]
        ) grants
        ++ [
          {
            name = "store-install";
            image = ref images."library/busybox";
            command = [
              "/bin/sh"
              "-c"
              installScript
            ];
            securityContext = hardened;
            volumeMounts = [ dataMount ];
          }
          {
            name = "store-backup";
            image = ref images."library/python";
            command = [
              "python3"
              "-I"
              "-c"
              backupScript
            ];
            securityContext = hardened;
            volumeMounts = [
              dataMount
              (roMount "gateway-image" "/nix" // { subPath = "nix"; })
              (roMount "gateway-image" gatewayBinDir // { subPath = "bin"; })
            ];
          }
        ];

        installScript = ''
          set -eu
          if [ -e ${grantStore} ]; then
            echo "${grantStore} present: left unchanged"
          else
            mv ${stagedStore} ${grantStore}
            echo "${grantStore} created: grant ${grantId} enrolled, disabled at revision 1"
          fi
          rm -rf ${stagingDir}
        '';

        # The decision is the gateway's migrations-pending; only exit 10 backs the store
        # up (the sqlite3 backup API, never cp), and the copy is verified. Any exit but
        # 0 and 10 fails here, before any backup.
        #
        # A gateway killed mid-transaction (a node lost with the pod, 2026-11-13) leaves a
        # hot rollback journal. migrations-pending opens read-only, which cannot roll it
        # back, so every start would fail "authority store unavailable". So first: the
        # database and its journal are copied as found (byte copies, the only faithful
        # record of a hot journal), then one read-write open lets SQLite roll the journal
        # back to the last committed state, as the gateway's own open would.
        backupScript = ''
          import os, shutil, sqlite3, subprocess, sys, time
          os.umask(0o077)
          journal = "${grantStore}-journal"
          if os.path.exists(journal) and os.path.getsize(journal) > 0:
              os.makedirs("${backupsDir}", mode=0o700, exist_ok=True)
              out = "${backupsDir}/grants.db.hot-journal-" + time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
              shutil.copyfile("${grantStore}", out)
              shutil.copyfile(journal, out + "-journal")
              fd = os.open("${backupsDir}", os.O_RDONLY)
              os.fsync(fd)
              os.close(fd)
              db = sqlite3.connect("${grantStore}")
              ok = db.execute("PRAGMA quick_check").fetchone()[0] == "ok"
              db.close()
              if not ok:
                  sys.exit("${grantStore}: quick_check failed after rolling back the hot journal; copies at " + out)
              print("${grantStore}: rolled back a hot journal; the database and journal as found are at " + out)
          r = subprocess.run(["${gatewayBin}", "--state", "${grantStore}", "migrations-pending"], stdout=subprocess.PIPE, text=True)
          if r.returncode == 0:
              print("${grantStore}: no migration pending, no backup")
              sys.exit(0)
          if r.returncode != 10:
              sys.exit("${grantStore}: migrations-pending exited " + str(r.returncode))
          src = sqlite3.connect("file:${grantStore}?mode=ro", uri=True)
          app = src.execute("PRAGMA application_id").fetchone()[0]
          os.makedirs("${backupsDir}", mode=0o700, exist_ok=True)
          out = "${backupsDir}/grants.db.pre-migrate-" + time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
          dst = sqlite3.connect(out + ".partial")
          src.backup(dst)
          ok = dst.execute("PRAGMA application_id").fetchone()[0] == app and dst.execute("PRAGMA quick_check").fetchone()[0] == "ok"
          dst.close()
          if not ok:
              sys.exit(out + ".partial: backup failed verification")
          os.replace(out + ".partial", out)
          fd = os.open("${backupsDir}", os.O_RDONLY)
          os.fsync(fd)
          os.close(fd)
          print("${grantStore}: backed up to " + out + " before " + ", ".join(r.stdout.split()))
          # A migration left pending on purpose (the AS cutover) backs up on every start:
          # keep the newest ${toString keepPreMigrate} pre-migrate copies. Only that prefix; hot-journal
          # copies and the gateway's <db>.recovery/ are never pruned. Names sort by time.
          olds = sorted(f for f in os.listdir("${backupsDir}") if f.startswith("grants.db.pre-migrate-") and not f.endswith(".partial"))
          for f in olds[:-${toString keepPreMigrate}]:
              os.remove(os.path.join("${backupsDir}", f))
              print("${backupsDir}: pruned " + f)
          st = os.statvfs("${backupsDir}")
          print("${backupsDir}: backup " + str(os.path.getsize(out)) + " B; volume free " + str(st.f_bavail * st.f_frsize) + " of " + str(st.f_blocks * st.f_frsize) + " B; kept " + str(min(len(olds), ${toString keepPreMigrate})) + " pre-migrate")
        '';

        egressRule =
          to: port:
          to
          // {
            toPorts = [
              {
                ports = [
                  {
                    port = toString port;
                    protocol = "TCP";
                  }
                ];
              }
            ];
          };
      in
      lib.optionalAttrs (enabledFor cluster images) {
        applications.${name} = {
          inherit namespace;

          # The chart always renders the Deployment, so the release is withheld whole.
          helm.releases =
            lib.optionalAttrs
              (lib.warnIf (cfg.subject == null)
                "xmsg-gateway: settings.subject is unset, so the gateway release is withheld. Set it to the owner's kanidm `sub` (person UUID) measured from one real token's introspection."
                (cfg.subject != null)
              )
              {
                ${name} = {
                  chart = "${inputs.xmsg-mcp-gateway-chart}/charts/xmsg-mcp-gateway";
                  values = {
                    fullnameOverride = name;
                    serviceAccount.name = name;
                    image = image "sini/xmsg-mcp-gateway";
                    helperImage = image "library/busybox";
                    # Bound on the pod network for envoy (allow_non_loopback_bind); the
                    # ingress policy below admits only the gateways namespace.
                    gateway.podNetwork = true;
                    inherit serving;
                    # Read only by `prepare`, which copies them owner-private into keys/.
                    secrets = {
                      existingSecret = name;
                      items = [
                        {
                          key = "lookup-secret";
                          mode = "0400";
                        }
                        {
                          key = "events-key";
                          mode = "0600";
                          base64Decode = true;
                        }
                      ]
                      ++ lib.optionals asEnabled [
                        {
                          key = "as-client-secret";
                          mode = "0400";
                        }
                        {
                          key = "liveness-token";
                          mode = "0400";
                        }
                      ];
                    };
                    store = {
                      eventsKey = "events-key";
                      # Hash-only OAuth state; with the AS on only, so the owner's
                      # maintenance window (not a routine restart) first ran it (§2.10 step 3).
                      authorizationServer = asEnabled;
                      inherit grants;
                      preMigrate = stagedChain;
                    };
                    xmsg = {
                      image = image "sini/xmsg";
                      principal = service;
                      tls.existingSecret = "${name}-xmsg-tls";
                      inherit peers;
                    };
                    tunnel = {
                      enabled = cfg.tunnel.enable;
                    }
                    // lib.optionalAttrs cfg.tunnel.enable {
                      image = image "openai/tunnel-client";
                      inherit (cfg.tunnel) id;
                      apiKeySecret.name = name;
                      # tunnel-client fetches the authorization server's metadata only from
                      # trusted origins (measured 2026-11-10: "destination origin is not
                      # trusted" for kanidm), and harpoon, the channel OpenAI sends tool calls
                      # on, forwards OAuth only to an approved origin: kanidm's, where the
                      # advertised issuer lives, and the gateway's public origin, which serves
                      # the protected-resource metadata (measured 2026-11-16).
                      oauthOrigins = [
                        "https://${kanidmDomain}"
                        origin
                      ];
                    };
                    # SQLite grant store, custody and the leaf's db. The media-config label
                    # enrolls it in Longhorn's nightly off-cluster backup (storage/longhorn).
                    persistence = {
                      storageClassName = "longhorn";
                      labels."recurring-job-group.longhorn.io/media-config" = "enabled";
                    };
                    # Only OAuth discovery and the authorization server's endpoints are
                    # public; an unmatched path on this host 404s at envoy. Route B
                    # (ingress-route amendment, ng1.32), /mcp over direct HTTPS for the
                    # connector the gateway's AS serves, with the AS only.
                    httpRoute = {
                      enabled = true;
                      hostnames = [ (lib.removePrefix "https://" origin) ];
                      parentRefs = [
                        {
                          name = "default-gateway";
                          namespace = "gateways";
                          sectionName = "${cluster.resourceForDomain (lib.removePrefix "https://" origin)}-https";
                        }
                      ];
                      mcp = asEnabled;
                    };
                    # The Loki ruler's rule ConfigMaps (monitoring/loki.nix). The store
                    # filling silently wedged Artemis's inbound on 2026-11-22 (xmsg-lxd2).
                    custodyAlerts = {
                      enabled = true;
                      namespace = "monitoring";
                      labels.loki_rule = "true";
                    };
                    # The gateway image itself, for store-backup's migrations-pending.
                    extraVolumes = [
                      {
                        name = "gateway-image";
                        image.reference = gatewayImage;
                      }
                    ];
                  };
                };
              };

          resources = {
            certificates.${name}.spec = {
              secretName = "${name}-xmsg-tls";
              issuerRef = {
                name = issuer;
                kind = "ClusterIssuer";
                group = "cert-manager.io";
              };
              uris = [ "spiffe://${domainOf cluster}/ns/${namespace}/sa/${name}" ];
              usages = [
                "digital signature"
                "key encipherment"
                "server auth"
                "client auth"
              ];
              # Short-lived: expiry stands in for revocation (plan §6.7).
              duration = "24h";
              renewBefore = "8h";
              privateKey = {
                algorithm = "ECDSA";
                size = 256;
                encoding = "PKCS8";
                rotationPolicy = "Always";
              };
            };

            secrets.${name}.stringData = {
              events-key = config.age.secrets.xmsg-gateway-events-key.sopsRef;
              lookup-secret = config.age.secrets.xmsg-gateway-lookup-oidc-client-secret.sopsRef;
              tunnel-runtime-key = config.age.secrets.xmsg-gateway-tunnel-runtime-key.sopsRef;
            }
            // lib.optionalAttrs asEnabled {
              as-client-secret = config.age.secrets.xmsg-gateway-as-client-secret.sopsRef;
              liveness-token = config.age.secrets.xmsg-gateway-liveness-token.sopsRef;
            };

            # Per client address, as envoy-gateway detects it: Cloudflare's forwarded
            # client when the peer is a Cloudflare edge, else the peer itself
            # (envoy-gateway.nix clientIPDetection). A forged header changes nothing.
            backendTrafficPolicies."${name}-authorize-rate-limit".spec = {
              targetRefs = [
                {
                  group = "gateway.networking.k8s.io";
                  kind = "HTTPRoute";
                  name = "${name}-authorize";
                }
              ];
              rateLimit.local.rules =
                map
                  (value: {
                    clientSelectors = [
                      {
                        sourceCIDR = {
                          type = "Distinct";
                          inherit value;
                        };
                      }
                    ];
                    limit = {
                      requests = 30;
                      unit = "Minute";
                    };
                  })
                  [
                    "0.0.0.0/0"
                    "::/0"
                  ];
            };

            # Route B's unauthenticated-traffic bound per client address (§2.5): ten times
            # the authorize bound, for a client's normal tool-call bursts; 429 beyond it.
            backendTrafficPolicies."${name}-mcp-rate-limit" = lib.mkIf asEnabled {
              spec = {
                targetRefs = [
                  {
                    group = "gateway.networking.k8s.io";
                    kind = "HTTPRoute";
                    name = "${name}-mcp";
                  }
                ];
                rateLimit.local.rules =
                  map
                    (value: {
                      clientSelectors = [
                        {
                          sourceCIDR = {
                            type = "Distinct";
                            inherit value;
                          };
                        }
                      ];
                      limit = {
                        requests = 300;
                        unit = "Minute";
                      };
                    })
                    [
                      "0.0.0.0/0"
                      "::/0"
                    ];
              };
            };

            # Declaring an ingress rule puts the pod in ingress default-deny: only envoy
            # reaches the plaintext listener. The tunnel sidecar connects over loopback.
            ciliumNetworkPolicies."${name}-ingress".spec = {
              description = "xmsg-gateway: envoy-gateway only, on ${toString port}.";
              endpointSelector.matchLabels = selectorLabels;
              ingress = [
                {
                  fromEndpoints = [ { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; } ];
                  toPorts = [
                    {
                      ports = [
                        {
                          port = toString port;
                          protocol = "TCP";
                        }
                      ];
                    }
                  ];
                }
              ];
            };

            ciliumClusterwideNetworkPolicies."allow-xmsg-egress-${namespace}-${name}".spec = {
              description = "Allow ${namespace}/${name} to its xmsg hubs' federation ports, kanidm's introspection, and public HTTPS for Events callbacks.";
              endpointSelector.matchExpressions = [
                {
                  key = "k8s:io.kubernetes.pod.namespace";
                  operator = "In";
                  values = [ namespace ];
                }
                {
                  key = "k8s:io.cilium.k8s.policy.serviceaccount";
                  operator = "In";
                  values = [ name ];
                }
              ];
              egress = map (h: egressRule { toCIDR = [ "${h.ip}/32" ]; } h.port) hubs ++ [
                # Events callbacks go to the subscriber's public HTTPS URL, unknown in
                # advance (amendment §2.1: "the public callback destination on 443").
                # This also carries the tunnel sidecar's control plane, api.openai.com.
                (egressRule { toEntities = [ "world" ]; } 443)
              ];
            };
          };
        };
      };
  };
}
