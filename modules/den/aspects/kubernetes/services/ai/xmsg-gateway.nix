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
# Grant store (events.md "Configure and migrate", serving.md). The chart's bootstrap
# runs on the real store: `init --if-needed` creates it only when absent (an existing
# one prints `already initialized` after a read-only open), then `store-backup`, every
# migrate-* with --if-needed, `enroll --if-needed` per grant and `apply`. enroll after
# the migrations makes a new grant's never-enabled history explicit; an existing grant
# whose exact binding differs fails the pod (EnrollmentConflict), never rewritten. A
# new grant is disabled at revision 1: `enable` is never run here. It is a deliberate
# one-time cutover step
# (`xmsg-mcp-gateway --state /var/lib/xmsg-mcp-gateway/state/grants.db enable chatgpt 1`).
#
# Migrations: --if-needed migrates a store that needs it and otherwise prints `already
# migrated` and exits 0 without writing; unknown markers, unsupported schemas and
# partial migrations still fail (serving.md). Retirement and custody summaries are
# one-way (older images refuse their application_id), so `store-backup`, in the
# chart's store.preMigrate slot, is the gateway's `backup-if-pending` (serving.md
# "Snapshot before a pending migration"): only with a migration pending does it publish
# an online backup (the SQLite backup API) to backups/gateway-backup-v1-*/ and keep the
# newest keepPreMigrate. A hot rollback journal left by a killed writer is recovered by
# the first read-only open (store-init's), after byte copies of the database and journal
# as found go to grants.db.recovery/ (serving.md "Crash recovery during inspection").
# Any failure fails the pod before a migration. Rolling back to an older image means
# restoring that backup.
#
# Outbound policy (outbound.md, `apply`): `store-apply`, the last step, then applies
# policy.json, the grant's send and reply targets (every hub's sessions), to the real
# store. apply compares policies as typed values and an unchanged one prints `unchanged
# at revision N`, writes nothing and exits 0, so a restart is a no-op. A change advances
# the revision by one (and, like set-outbound-policy, pauses the Events subscription).
# No --enabled or --disabled: apply keeps the grant's enablement. The grant always
# exists here (the bootstrap enrolls it), and a missing one fails the pod.
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
# Gating check: xmsg-gateway-check.nix, over axon's rendered manifests.
{
  config,
  den,
  lib,
  inputs,
  rootPath,
  ...
}:
let
  topConfig = config;
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
  # values and the backup step refer to.
  tlsDir = "/etc/xmsg/tls";
  configDir = "/etc/xmsg-mcp-gateway";
  dataDir = "/var/lib/xmsg-mcp-gateway";
  stateDir = "${dataDir}/state";
  # The chart's `prepare` copies each secrets item to <keysDir>/<item key>.
  keysDir = "/run/xmsg-mcp-gateway/keys";
  grantStore = "${stateDir}/grants.db";
  backupsDir = "${dataDir}/backups";
  # store-backup keeps this many pre-migrate backups (xmsg-design, 2026-11-13).
  keepPreMigrate = 3;
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
    url = "github:sini/xmsg-mcp-gateway/fecf6200a8392c2750eb5273abe93d3cd51d7be8";
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
        description = "The host whose owner's xmsg is the leaf's hub. That node takes the leaf from `lib.fleet.xmsg.leaves`. Required with enable.";
      };

      extraHubs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "bitstream" ];
        description = "More hosts whose owner's xmsg is also the leaf's hub, so the gateway reaches and lists their sessions too. Each takes the leaf from `lib.fleet.xmsg.leaves`.";
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
        gatewaySelf = "${name}.${namespace}";
        fleetPeers = inputs.xmsg.lib.fleet.peersRenderedFor {
          fleet = topConfig.xmsg.fleet;
          self = gatewaySelf;
        };
        fleetFinal = inputs.xmsg.lib.fleet.checkFinal {
          value = topConfig.xmsg.fleet;
          self = gatewaySelf;
          file = fleetPeers;
          hostOwned = [ ];
        };
        fleetReach = inputs.xmsg.lib.fleet.reachableFor {
          fleet = topConfig.xmsg.fleet;
          self = gatewaySelf;
        };
        expectedRelayed = lib.optionals ((cfg.relayed or [ ]) != [ ]) [
          {
            via = primary.name;
            to = lib.sort builtins.lessThan (cfg.relayed or [ ]);
          }
        ];
        peers =
          assert lib.assertMsg (
            fleetFinal == [ ]
          ) "xmsg-gateway: checkFinal failed: ${builtins.toJSON fleetFinal}";
          fleetPeers;

        # The grant's outbound policy: each hub's sessions, for send and for reply. The
        # chart writes it as JSON (keys sorted); apply compares typed values.
        permission =
          scope:
          assert lib.assertMsg (
            fleetReach.direct == lib.sort builtins.lessThan (map (h: h.name) hubs)
            && fleetReach.relayed == expectedRelayed
          ) "xmsg-gateway: policy targets do not match lib.fleet.reachableFor.";
          {
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

        dataMount = {
          name = "data";
          mountPath = dataDir;
        };

        gatewayImage = ref images."sini/xmsg-mcp-gateway";
        image = i: { inherit (images.${i}) repository digest; };
        # The chart's selector labels (_helpers.tpl gw.selectorLabels), for the policies.
        selectorLabels = {
          "app.kubernetes.io/name" = "xmsg-mcp-gateway";
          "app.kubernetes.io/instance" = name;
        };

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

        # store.preMigrate: the gateway's own pre-migration backup, on the real store
        # after the chart's `init --if-needed` and before its migrations; see the header.
        backupStep = {
          name = "store-backup";
          image = gatewayImage;
          args = [
            "--state"
            grantStore
            "backup-if-pending"
            "--backup-dir"
            backupsDir
            "--keep"
            (toString keepPreMigrate)
          ];
          securityContext = hardened;
          volumeMounts = [ dataMount ];
        };

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
                      bootstrap.enabled = true;
                      preMigrate = [ backupStep ];
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
