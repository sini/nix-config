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
# The one inbound path is the MCP listener on loopback, reached through the
# tunnel-client sidecar (settings.tunnel, off until cutover). No Service, no ingress.
#
# One uid on every container: the leaf admits register.sock and agent.sock callers by
# SO_PEERCRED uid, and the gateway's messaging.xmsg.daemon_uid must equal the leaf's.
# 10001 is the gateway image's own user.
#
# The gateway refuses group- or world-accessible credential files and a state
# directory others can write, and its Events key must be exactly 0600 and owned by
# the owner of its directory. Kubernetes Secret files are root-owned, so the `prepare`
# initContainer (busybox, as this uid) copies the secrets into a memory emptyDir
# directory it owns (lookup secret 0400, Events key 0600), and makes the PVC's state
# directories 0700. The PVC keeps fsGroupChangePolicy OnRootMismatch, so kubelet never
# re-adds group write to them on a later mount.
#
# Grant store (events.md "Configure and migrate"). Initialization never overwrites and
# no-op migrations fail, so the real store is created only when absent. The gateway
# image has no shell, so the steps cannot be skipped by a test inside it: they always
# build a fresh store in a staging directory on the PVC (init, migrate-custody,
# migrate-outbound, migrate-retirement, migrate-events, enroll), and the last busybox
# step moves it into
# place only if state/grants.db is absent. Otherwise it discards it. A crash between
# steps therefore never leaves a half-built real store. The grant stays disabled at
# revision 1: `enable` is never run here. It is a deliberate one-time cutover step
# (`xmsg-mcp-gateway --state /var/lib/xmsg-mcp-gateway/state/grants.db enable chatgpt 1`).
#
# Retirement migration (outbound.md): `migrate-retirement` changes the store's SQLite
# application_id from 0x584d4757 to 0x584d4752. Older gateways then refuse the store,
# and a second run fails. The gateway CLI has no status or backup verb, so the
# `store-retirement-inspect` step (the pinned python image, for its sqlite3 module)
# reads the real store's application_id. Only when it is the legacy marker does it take
# an online backup (the sqlite3 backup API, never cp) to
# backups/grants.db.pre-retirement-<UTC time> and point the staging link at the real
# store. Otherwise the link points at the staged store, which needs the migration
# anyway. `store-migrate-retirement` then runs once, on the link. SQLite resolves the
# symlink, so the real store's journal stays beside it. A crash before the commit leaves
# the legacy marker, so the next start backs up and migrates again. Rolling back to an
# older image means restoring that backup.
#
# Backup: the Events key encrypts the store's callback URLs, delivery secrets and
# retained tokens, so the store is useless without it. The key lives in agenix (git)
# and the PVC joins Longhorn's nightly off-cluster backup group (media-config). Restore
# both together.
#
# Gating check: xmsg-gateway-check.nix, over this aspect's manifests with the flag
# forced on.
{
  den,
  lib,
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
  # The dedicated hosted client (services/security/kanidm.nix), and its lookup twin.
  hostedClient = "xmsg-gateway";
  lookupClient = "xmsg-gateway-lookup";
  uid = 10001;
  issuer = "xmsg-cluster-ca";
  listen = "127.0.0.1:8787";

  runtimeDir = "/run/user";
  tlsDir = "/etc/xmsg/tls";
  peersDir = "/etc/xmsg/peers";
  configDir = "/etc/xmsg-mcp-gateway";
  dataDir = "/var/lib/xmsg-mcp-gateway";
  stateDir = "${dataDir}/state";
  stagingDir = "${dataDir}/staging";
  leafDb = "${dataDir}/xmsg/xmsg.db";
  keysDir = "/run/xmsg-mcp-gateway/keys";
  secretsDir = "/run/secrets/${name}";
  grantStore = "${stateDir}/grants.db";
  stagedStore = "${stagingDir}/grants.db";
  # What migrate-retirement runs on: a symlink to the real or the staged store.
  retirementLink = "${stagingDir}/retirement.db";
  backupsDir = "${dataDir}/backups";
  eventsKey = "${keysDir}/events.key";
  lookupSecret = "${keysDir}/lookup-secret";

  # The node limits the gateway's manifest must equal. They are xmsg's defaults
  # (xmsg src/main.rs ServeArgs at 27429b7: --reply-ttl 604800, --idempotency-ttl 86400,
  # --svc-queue-cap storage::MAX_SVC_QUEUE_PER_SESSION = 100, --max-body
  # storage::DEFAULT_MAX_BODY_BYTES = 65536), passed to the leaf explicitly from this
  # one binding, so the two sides agree by construction.
  node-limits = {
    reply-ttl = 604800;
    idempotency-ttl = 86400;
    svc-queue-cap = 100;
    max-body = 65536;
  };

  # Budgets (serving.md, events.md). The store's busy wait is the gateway's own 30 s
  # (grants.rs Store::open).
  timeouts = {
    verifier = 5000;
    storeWait = 30000;
    submission = 20000;
    dispatch = 16000;
    request = 60000;
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

  # The budget rules the gateway enforces at startup, refused here at eval instead.
  budgetAssertions = [
    {
      ok = timeouts.dispatch >= timeouts.verifier + 11000 && timeouts.dispatch <= 60000;
      msg = "events.dispatch_timeout_ms must be >= verifier.timeout_ms + 11000 and <= 60000";
    }
    {
      ok = timeouts.request >= 2 * timeouts.verifier + 41000 && timeouts.request <= 60000;
      msg = "request_timeout_ms must be >= 2 * verifier.timeout_ms + 41000 and <= 60000";
    }
    {
      ok =
        timeouts.submission <= 25000
        && timeouts.request >= timeouts.verifier + timeouts.storeWait + timeouts.submission;
      msg = "request_timeout_ms must cover verifier.timeout_ms + the 30 s store wait + submission_timeout_ms (<= 25000)";
    }
  ];
  checkBudgets =
    v:
    let
      bad = lib.filter (a: !a.ok) budgetAssertions;
    in
    if bad == [ ] then v else throw "xmsg-gateway: ${lib.concatMapStringsSep "; " (a: a.msg) bad}";
in
{
  den.aspects.kubernetes.services.ai.xmsg-gateway = {
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
          # Explicitly every target. One `targets` list gates both what the hub queues
          # to the leaf and what the leaf may reach on the hub. The hub's agent sessions
          # are instance ids, which no fixed list can name, so a list would refuse every
          # send to them. Inbound, the leaf hosts the one principal and refuses any
          # other name. The gateway's per-grant outbound policy (`set-outbound-policy`)
          # is what narrows its sends.
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
        kanidmIp = lib.head kanidmHost.ipv4;
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

        peers = lib.listToAttrs (
          map (h: {
            inherit (h) name;
            value = {
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

        # The exact enrollment document; the verifier's values below are the same.
        binding = {
          inherit service resource;
          issuer = verifierIssuer;
          subject = cfg.subject;
          hosted_client = hostedClient;
        };

        serving = checkBudgets {
          bind = listen;
          grant_store = grantStore;
          request_timeout_ms = timeouts.request;
          allowed_hosts = [
            "127.0.0.1"
            "localhost"
            (lib.removePrefix "https://" origin)
          ];
          allowed_origins = [ ];
          verifier = {
            inherit service resource;
            inherit (binding) issuer subject hosted_client;
            # Kanidm sets aud to the client name (provider-setup.md "Direct Kanidm").
            audience = hostedClient;
            introspection_url = "https://${kanidmDomain}/oauth2/token/introspect";
            introspection_client = lookupClient;
            client_secret_file = lookupSecret;
            # In-cluster DNS answers kanidm's name with this host's address too
            # (coredns served-domains); the pin needs no DNS and matches the egress rule.
            provider_addresses = [ kanidmIp ];
            required_scopes = [
              "identity:read"
              "events:subscribe"
              "xmsg:send"
              "xmsg:reply"
            ];
            timeout_ms = timeouts.verifier;
          };
          messaging = {
            xmsg = {
              inherit service;
              expected_node = node;
              daemon_uid = uid;
              register_socket = "${runtimeDir}/xmsg/register.sock";
              agent_socket = "${runtimeDir}/xmsg/agent.sock";
            };
            manifest = {
              reply_ttl_secs = node-limits.reply-ttl;
              idempotency_ttl_secs = node-limits.idempotency-ttl;
              svc_queue_cap = node-limits.svc-queue-cap;
              # Half the node's idempotency window: a retry always lands well inside it.
              dedup_lifetime_secs = node-limits.idempotency-ttl / 2;
              max_framed_bytes = node-limits.max-body;
            };
            submission_timeout_ms = timeouts.submission;
            max_reservations = 1000;
            max_retained_bytes = 67108864;
          };
          events = {
            key_file = eventsKey;
            grant_id = grantId;
            dispatch_timeout_ms = timeouts.dispatch;
          };
        };

        mount = vol: path: {
          name = vol;
          mountPath = path;
        };
        roMount = vol: path: mount vol path // { readOnly = true; };
        tmpMount = mount "tmp" "/tmp";
        dataMount = mount "data" dataDir;

        busybox = ref images."library/busybox";
        python = ref images."library/python";
        gatewayImage = ref images."sini/xmsg-mcp-gateway";

        # Each store step is the gateway CLI itself, on the staged store.
        storeStep = step: args: {
          name = "store-${step}";
          image = gatewayImage;
          args = [
            "--state"
            stagedStore
          ]
          ++ args;
          securityContext = hardened;
          volumeMounts = [
            dataMount
            (roMount "keys" (dirOf keysDir))
            (roMount "config" configDir)
          ];
        };

        prepareScript = ''
          set -eu
          umask 077
          mkdir -p ${stateDir} ${dirOf leafDb} ${keysDir}
          chmod 0700 ${stateDir} ${dirOf leafDb} ${keysDir}
          rm -rf ${stagingDir}
          mkdir ${stagingDir}
          rm -f ${lookupSecret} ${eventsKey}
          cp ${secretsDir}/lookup-secret ${lookupSecret}
          chmod 0400 ${lookupSecret}
          base64 -d ${secretsDir}/events-key > ${eventsKey}
          chmod 0600 ${eventsKey}
          [ "$(wc -c < ${eventsKey})" -eq 32 ] || { echo "events key is not 32 bytes" >&2; exit 1; }
        '';

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

        # LEGACY and RETIREMENT are the application_ids in grants.rs.
        retirementInspectScript = ''
          import os, sqlite3, sys, time
          LEGACY, RETIREMENT = 0x584d4757, 0x584d4752
          os.umask(0o077)
          target = "${stagedStore}"
          if os.path.exists("${grantStore}"):
              src = sqlite3.connect("file:${grantStore}?mode=rw", uri=True)
              app = src.execute("PRAGMA application_id").fetchone()[0]
              if app == LEGACY:
                  os.makedirs("${backupsDir}", mode=0o700, exist_ok=True)
                  out = "${backupsDir}/grants.db.pre-retirement-" + time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
                  dst = sqlite3.connect(out + ".partial")
                  src.backup(dst)
                  ok = dst.execute("PRAGMA application_id").fetchone()[0] == LEGACY and dst.execute("PRAGMA quick_check").fetchone()[0] == "ok"
                  dst.close()
                  if not ok:
                      sys.exit(out + ".partial: backup failed verification")
                  os.replace(out + ".partial", out)
                  fd = os.open("${backupsDir}", os.O_RDONLY)
                  os.fsync(fd)
                  os.close(fd)
                  print("${grantStore}: legacy store backed up to " + out + ", migrating")
                  target = "${grantStore}"
              elif app == RETIREMENT:
                  print("${grantStore}: already migrated, left unchanged")
              else:
                  sys.exit("${grantStore}: unrecognized application_id " + hex(app))
              src.close()
          os.symlink(target, "${retirementLink}")
        '';

        tunnelContainer = {
          name = "tunnel-client";
          image = ref images."openai/tunnel-client";
          # The image's entrypoint is `tunnel-client run`; these follow it. tunnel-client
          # fetches the authorization server's metadata only from trusted origins (measured
          # 2026-11-10: "destination origin is not trusted" for kanidm), and the issuer the
          # gateway advertises (verifierIssuer) lives on kanidm's origin.
          args = [
            "--mcp.oauth-trusted-origin"
            "https://${kanidmDomain}"
          ];
          env = [
            {
              name = "CONTROL_PLANE_TUNNEL_ID";
              value = cfg.tunnel.id;
            }
            {
              name = "CONTROL_PLANE_BASE_URL";
              value = "https://api.openai.com";
            }
            {
              name = "MCP_SERVER_URL";
              value = "http://${listen}/mcp";
            }
            # The gateway may bind after the sidecar starts; wait before the first poll
            # so a queued command is not consumed early (kubernetes-sidecar.md).
            {
              name = "MCP_STARTUP_WAIT_TIMEOUT";
              value = "60s";
            }
            {
              name = "HOME";
              value = "/tmp";
            }
            {
              name = "CONTROL_PLANE_API_KEY";
              valueFrom.secretKeyRef = {
                inherit name;
                key = "tunnel-runtime-key";
              };
            }
          ];
          securityContext = hardened;
          volumeMounts = [ tmpMount ];
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

          resources = {
            serviceAccounts.${name}.automountServiceAccountToken = false;

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

            configMaps."${name}-xmsg-peers".data."peers.json" = builtins.toJSON peers;

            # Nonsecret: world-readable, never writable (serving.md "Owner configuration").
            configMaps."${name}-config".data = {
              "serving.json" = builtins.toJSON serving;
              "binding.json" = builtins.toJSON binding;
            };

            secrets.${name}.stringData = {
              events-key = config.age.secrets.xmsg-gateway-events-key.sopsRef;
              lookup-secret = config.age.secrets.xmsg-gateway-lookup-oidc-client-secret.sopsRef;
              tunnel-runtime-key = config.age.secrets.xmsg-gateway-tunnel-runtime-key.sopsRef;
            };

            # SQLite grant store, custody and the leaf's db. The media-config label
            # enrolls it in Longhorn's nightly off-cluster backup (storage/longhorn).
            persistentVolumeClaims.${name} = {
              metadata.labels."recurring-job-group.longhorn.io/media-config" = "enabled";
              spec = {
                accessModes = [ "ReadWriteOnce" ];
                storageClassName = "longhorn";
                resources.requests.storage = "1Gi";
              };
            };

            deployments =
              lib.optionalAttrs
                (lib.warnIf (cfg.subject == null)
                  "xmsg-gateway: settings.subject is unset, so the Deployment is withheld. Set it to the owner's kanidm `sub` (person UUID) measured from one real token's introspection."
                  (cfg.subject != null)
                )
                {
                  ${name}.spec = {
                    replicas = 1;
                    # One SQLite writer on a ReadWriteOnce volume.
                    strategy.type = "Recreate";
                    selector.matchLabels."app.kubernetes.io/name" = name;
                    template = {
                      metadata.labels."app.kubernetes.io/name" = name;
                      # A config change must restart the pod: the gateway reads serving.json and
                      # the leaf reads peers.json only at start.
                      metadata.annotations."json64.dev/config-hash" = builtins.hashString "sha256" (
                        builtins.toJSON [
                          serving
                          binding
                          peers
                        ]
                      );
                      spec = {
                        serviceAccountName = name;
                        automountServiceAccountToken = false;
                        enableServiceLinks = false;
                        securityContext = {
                          runAsUser = uid;
                          runAsGroup = uid;
                          runAsNonRoot = true;
                          fsGroup = uid;
                          fsGroupChangePolicy = "OnRootMismatch";
                          seccompProfile.type = "RuntimeDefault";
                        };
                        initContainers = [
                          {
                            name = "prepare";
                            image = busybox;
                            command = [
                              "/bin/sh"
                              "-c"
                              prepareScript
                            ];
                            securityContext = hardened;
                            volumeMounts = [
                              dataMount
                              (mount "keys" (dirOf keysDir))
                              (roMount "secrets" secretsDir)
                            ];
                          }
                          (storeStep "init" [ "init" ])
                          (storeStep "migrate-custody" [ "migrate-custody" ])
                          (storeStep "migrate-outbound" [ "migrate-outbound" ])
                          {
                            name = "store-retirement-inspect";
                            image = python;
                            command = [
                              "python3"
                              "-I"
                              "-c"
                              retirementInspectScript
                            ];
                            securityContext = hardened;
                            volumeMounts = [ dataMount ];
                          }
                          # The real store only when inspect found it legacy.
                          (
                            storeStep "migrate-retirement" [ ]
                            // {
                              args = [
                                "--state"
                                retirementLink
                                "migrate-retirement"
                              ];
                            }
                          )
                          (storeStep "migrate-events" [
                            "migrate-events"
                            "--key-file"
                            eventsKey
                          ])
                          (storeStep "enroll" [
                            "enroll"
                            grantId
                            "${configDir}/binding.json"
                          ])
                          {
                            name = "store-install";
                            image = busybox;
                            command = [
                              "/bin/sh"
                              "-c"
                              installScript
                            ];
                            securityContext = hardened;
                            volumeMounts = [ dataMount ];
                          }
                        ];
                        containers = [
                          {
                            name = "xmsg";
                            image = ref images."sini/xmsg";
                            args = [
                              "serve"
                              "--leaf"
                              "--leaf-principal"
                              service
                              # Required by --leaf; loopback in the pod's own netns.
                              "--listen"
                              "127.0.0.1:7787"
                              "--leaf-register-sock"
                              "${runtimeDir}/xmsg/register.sock"
                              "--agent-sock"
                              "${runtimeDir}/xmsg/agent.sock"
                              "--db-path"
                              leafDb
                              "--peers-file"
                              "${peersDir}/peers.json"
                              "--fed-cert"
                              "${tlsDir}/tls.crt"
                              "--fed-key"
                              "${tlsDir}/tls.key"
                            ]
                            ++ lib.concatLists (
                              lib.mapAttrsToList (flag: v: [
                                "--${flag}"
                                (toString v)
                              ]) node-limits
                            );
                            env = [
                              {
                                name = "XDG_RUNTIME_DIR";
                                value = runtimeDir;
                              }
                            ];
                            securityContext = hardened;
                            volumeMounts = [
                              (mount "run" runtimeDir)
                              tmpMount
                              dataMount
                              (roMount "tls" tlsDir)
                              (roMount "peers" peersDir)
                            ];
                          }
                          {
                            name = "gateway";
                            image = gatewayImage;
                            args = [
                              "serve"
                              "--config"
                              "${configDir}/serving.json"
                            ];
                            securityContext = hardened;
                            volumeMounts = [
                              (mount "run" runtimeDir)
                              tmpMount
                              dataMount
                              (roMount "keys" (dirOf keysDir))
                              (roMount "config" configDir)
                            ];
                          }
                        ]
                        ++ lib.optional cfg.tunnel.enable tunnelContainer;
                        volumes = [
                          {
                            name = "run";
                            emptyDir.medium = "Memory";
                          }
                          {
                            name = "keys";
                            emptyDir.medium = "Memory";
                          }
                          {
                            name = "tmp";
                            emptyDir = { };
                          }
                          {
                            name = "data";
                            persistentVolumeClaim.claimName = name;
                          }
                          {
                            name = "tls";
                            secret = {
                              secretName = "${name}-xmsg-tls";
                              defaultMode = 288; # 0440, read through fsGroup
                            };
                          }
                          {
                            name = "peers";
                            configMap.name = "${name}-xmsg-peers";
                          }
                          {
                            name = "config";
                            configMap = {
                              name = "${name}-config";
                              defaultMode = 292; # 0444
                            };
                          }
                          # Read only by `prepare` (through fsGroup), which copies them
                          # owner-private into the keys emptyDir.
                          {
                            name = "secrets";
                            secret = {
                              secretName = name;
                              items = [
                                {
                                  key = "events-key";
                                  path = "events-key";
                                }
                                {
                                  key = "lookup-secret";
                                  path = "lookup-secret";
                                }
                              ];
                              defaultMode = 288;
                            };
                          }
                        ];
                      };
                    };
                  };
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
                (egressRule { toCIDR = [ "${kanidmIp}/32" ]; } 443)
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
