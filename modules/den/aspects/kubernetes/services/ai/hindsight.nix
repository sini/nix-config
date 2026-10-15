# Hindsight — agent memory engine: retain (LLM fact extraction) + recall
# (hybrid semantic/BM25/graph search) over per-bank Postgres+pgvector storage.
#
# The dataplane API only (`hindsight-api`, the image upstream's own chart
# deploys). The all-in-one `hindsight` image is not used: it bundles an embedded
# postgres and the Next.js control plane, and state belongs in hindsight-pg.
#
# The dataplane has no HTTPRoute. Reach it via the ClusterIP service, the
# internal LoadBalancer below, or `kubectl -n ai port-forward svc/hindsight 8888`.
# The control-plane UI is served only at https://<domainFor "hindsight"> behind the
# gateway's kanidm OIDC, admins only (kanidm.nix `hindsight` client); nothing else
# reaches the CP pod.
#
# Auth. The dataplane reads `Authorization: Bearer <key>` into every request's
# context and runs it past two extension points: a TenantExtension (upstream ships
# ApiKeyTenantExtension, one key for every read and write on every bank, unused
# here) and an OperationValidatorExtension. This deployment loads one validator,
# hindsight-write-gate.py, configured from `gatedBanks`: each listed bank has its own
# token, which its writes need; a bank with gateReads needs it for reads too. Banks
# outside the list are open. The control plane holds an admin token the gate accepts
# on every listed bank; the dataplane holds only its SHA-256. Document import is
# switched off because it reaches no validator hook on an existing bank. Oracle:
# hindsight-write-gate-oracle.py, run against upstream's Python at the pinned
# version.
#
# Embeddings (BAAI/bge-small-en-v1.5) and reranking
# (cross-encoder/ms-marco-MiniLM-L-6-v2) run in-process on CPU at upstream
# defaults; both models are fetched from HuggingFace on first boot into the
# model-cache PVC, which is why this pod has world:443 egress.
{ den, lib, ... }:
let
  # Banks with their own token. One generated token per bank, so a holder of one
  # bank's token cannot use another gated bank. Writes always need it; gateReads
  # makes reads need it too. genie and genie-memory keep reads open because the
  # genie recall clients send no token (H2); den-law is the fleet's operating law.
  gatedBanks = {
    genie.gateReads = false;
    genie-memory.gateReads = false;
    den-law.gateReads = true;
  };
  gatedBankNames = builtins.attrNames gatedBanks;
  # A write-only token is named write-token-<bank>; a read-and-write one token-<bank>.
  tokenName = bank: if gatedBanks.${bank}.gateReads then "token-${bank}" else "write-token-${bank}";
  tokenSecret = bank: "hindsight-${tokenName bank}";
  serviceDomains = [ "hindsight" ];
in
{
  den.aspects.kubernetes.services.ai.hindsight = {
    # Hard dependency, not a coincidence of cluster composition: both LLM
    # endpoints and their model names are read out of this aspect's `instances`.
    includes = [ den.aspects.kubernetes.services.ai.llama-cpp ];

    service-domains = serviceDomains;
    served-domains = { cluster, ... }: cluster.servedDomains serviceDomains;

    # The single generator for each bank's token; the .age files are created by
    # `agenix generate`. Rekey targets of the same rekeyFile, with no generator of
    # their own: this pod (via sops), the genie token at services.ai.genie-bank-review
    # (sini@bitstream), the genie-memory token at services.ai.genie-memory-loader
    # (sini@cortex), and the den-law token at applications.dev.ai.mcp.hindsight (sini
    # on every host with the hindsight client).
    age-secrets =
      { environment, config, ... }:
      {
        age.secrets =
          lib.listToAttrs (
            map (
              bank:
              lib.nameValuePair (tokenSecret bank) {
                rekeyFile = environment.secretPath + "/hindsight/${tokenName bank}.age";
                generator.script = "hex";
                sopsOutput = {
                  file = "hindsight";
                  key = tokenName bank;
                };
              }
            ) gatedBankNames
          )
          // {
            # The control plane's admin token: a sops target of the CP pod only.
            # No trailing newline, because the CP sends the value verbatim in its
            # Authorization header.
            hindsight-cp-admin-token = {
              rekeyFile = environment.secretPath + "/hindsight/cp-admin-token.age";
              generator.script =
                { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 32 | ${pkgs.coreutils}/bin/tr -d '\\n'";
              sopsOutput = {
                file = "hindsight";
                key = "cp-admin-token";
              };
            };
            # Its SHA-256, derived from it, which is all the dataplane holds.
            hindsight-cp-admin-token-sha256 = {
              rekeyFile = environment.secretPath + "/hindsight/cp-admin-token-sha256.age";
              generator = {
                dependencies = [ config.age.secrets.hindsight-cp-admin-token ];
                script =
                  {
                    decrypt,
                    deps,
                    pkgs,
                    ...
                  }:
                  "${decrypt} ${lib.escapeShellArg (lib.head deps).file} | ${pkgs.coreutils}/bin/tr -d '\\n' | ${pkgs.coreutils}/bin/sha256sum | ${pkgs.coreutils}/bin/cut -d' ' -f1 | ${pkgs.coreutils}/bin/tr -d '\\n'";
              };
              sopsOutput = {
                file = "hindsight";
                key = "cp-admin-token-sha256";
              };
            };
            # The gateway's OIDC client secret; kanidm.nix declares the same
            # rekeyFile and generator for the `hindsight` client.
            hindsight-oidc-client-secret = {
              rekeyFile = environment.secretPath + "/oidc/hindsight-oidc-client-secret.age";
              generator = {
                tags = [ "oidc" ];
                script = "rfc3986-secret";
              };
              sopsOutput = {
                file = "oidc";
                key = "hindsight";
              };
            };
          };
      };

    k8s-manifests =
      {
        cluster,
        charts,
        images,
        config,
        ...
      }:
      let
        settings = cluster.settings.kubernetes.services.ai.hindsight;

        # An LLM key resolves in one of two spaces: an in-cluster llama-cpp
        # instance, or an off-cluster endpoint declared in externalLlms. Model
        # identity stays defined once, at the endpoint that serves it.
        llamaInstances = cluster.settings.kubernetes.services.ai.llama-cpp.instances;
        externals = settings.externalLlms;

        # Fully qualified for the same reason the postgres DSN is; see the note
        # in hindsight-pg.nix on the short form failing to resolve here.
        resolve =
          key:
          if llamaInstances ? ${key} then
            {
              url = "http://llama-cpp-${key}.ai.svc.cluster.local:8080/v1";
              inherit (llamaInstances.${key}) modelAlias;
              external = null;
              # SERVING CAPACITY, derived rather than written down: llama-server
              # takes LLAMA_ARG_N_PARALLEL concurrent requests per pod, and the
              # ClusterIP service load-balances across the replicas. Anything past
              # this queues INSIDE llama-server, which is the one queue that costs
              # a timeout — see the concurrency block below.
              slots = llamaInstances.${key}.replicas * llamaInstances.${key}.parallelSlots;
            }
          else if externals ? ${key} then
            {
              inherit (externals.${key}) url;
              modelAlias = externals.${key}.model;
              external = externals.${key};
              # An external endpoint's concurrency is not ours to know. null means
              # "do not cap from here" rather than a guessed number.
              slots = null;
            }
          else
            throw "hindsight: unknown LLM key '${key}' — llama-cpp instances: ${toString (builtins.attrNames llamaInstances)}; externalLlms: ${toString (builtins.attrNames externals)}";

        defaultLlm = resolve settings.defaultLlmInstance;
        retainLlm = resolve settings.retainLlmInstance;

        # Egress rules only for the external endpoints actually in use. An
        # unreferenced externalLlms entry is a declaration, not a hole in the
        # policy.
        usedExternals = lib.filter (e: e != null) [
          defaultLlm.external
          retainLlm.external
        ];

        port = 8888;
        cpPort = 3000;

        # The write gate is a Python module on PYTHONPATH, delivered as a
        # ConfigMap: upstream's loader imports any `module:Class` it can find, so
        # the pinned image runs unmodified.
        gateDir = "/opt/hindsight-write-gate";
        tokensDir = "/etc/hindsight-write-gate/tokens";
        adminDir = "/etc/hindsight-write-gate/admin";
      in
      {
        applications.hindsight = {
          namespace = "ai";

          helm.releases.hindsight = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers.main = {
                type = "deployment";

                # Single replica, deliberately. Retain work is claimed in
                # async_operations under HINDSIGHT_API_WORKER_ID below, and the
                # in-process worker (HINDSIGHT_API_WORKER_ENABLED, default true)
                # is the only consumer — a second replica would need the
                # separate worker StatefulSet upstream ships for that case.
                replicas = 1;

                # The image drops to USER hindsight (uid/gid 1000 — `useradd -m`
                # in upstream's Dockerfile, and its own comment says 1000), but a
                # freshly provisioned PVC mounts root-owned 0755. The model cache
                # below lands on one, so the embedder's first write fails with
                # "PermissionError at /home/hindsight/.cache/huggingface".
                # fsGroup makes the kubelet chown the volume to this GID and add
                # it to the container's supplementary groups; OnRootMismatch
                # keeps it from re-walking the whole cache on every start.
                pod.securityContext = {
                  fsGroup = 1000;
                  fsGroupChangePolicy = "OnRootMismatch";
                };

                # Release anything the previous incarnation of this worker was
                # holding. A pod that dies mid-retain (OOM, node loss, the crash
                # loop this deployment already went through) leaves its tasks in
                # 'processing' forever — the document sits in the bank with its
                # facts unextracted, which is silently unreachable by recall.
                # Graceful shutdown releases them; ungraceful termination is the
                # gap this closes.
                #
                # Only safe to do unconditionally because WORKER_ID is pinned and
                # replicas = 1: there is never another live worker whose tasks
                # this could steal. It is `|| true` on purpose — on a first
                # deploy the tables do not exist yet (migrations run in the main
                # container, after this), and a best-effort cleanup must never
                # block the startup that would create them.
                initContainers.release-stale-tasks = {
                  image = {
                    inherit (images."vectorize-io/hindsight-api") repository digest;
                  };
                  command = [
                    "sh"
                    "-c"
                    "hindsight-admin decommission-worker hindsight --yes || echo 'release-stale-tasks: skipped (see error above)'"
                  ];
                  env.HINDSIGHT_API_DATABASE_URL.valueFrom.secretKeyRef = {
                    name = "hindsight-pg-dsn";
                    key = "url";
                  };
                };

                containers.main = {
                  image = {
                    inherit (images."vectorize-io/hindsight-api") repository digest;
                  };

                  env = {
                    HINDSIGHT_API_HOST = "0.0.0.0";
                    HINDSIGHT_API_PORT = toString port;
                    HINDSIGHT_API_LOG_LEVEL = "info";

                    # A worker claims operations under this id and holds them in
                    # 'processing' until it reports back. Left unset it defaults
                    # to the hostname — the pod name — which churns on every
                    # restart, so in-flight work is orphaned under an identity
                    # that no longer exists and cannot be addressed afterwards.
                    #
                    # Pinning it does NOT make recovery automatic: upstream has
                    # no startup reclaim (decommission-worker exists only in the
                    # admin CLI, and its documented use case is "if a worker
                    # crashed while processing tasks"). What pinning buys is a
                    # KNOWN name to release, which the init container does.
                    HINDSIGHT_API_WORKER_ID = "hindsight";

                    HINDSIGHT_API_DATABASE_URL.valueFrom.secretKeyRef = {
                      name = "hindsight-pg-dsn";
                      key = "url";
                    };
                    # Upstream's default, stated explicitly because hindsight-pg
                    # provisions to match it (CREATE EXTENSION vector).
                    HINDSIGHT_API_VECTOR_EXTENSION = "pgvector";

                    # `openai`, not `llamacpp`: upstream's in-process llamacpp
                    # provider needs llama-cpp-python, which the published image
                    # deliberately omits (it fails with ModuleNotFoundError).
                    # Talking to a llama-server over its OpenAI-compatible API is
                    # the supported shape, and upstream's own local-llm compose
                    # example does exactly this.
                    HINDSIGHT_API_LLM_PROVIDER = "openai";
                    HINDSIGHT_API_LLM_BASE_URL = defaultLlm.url;
                    HINDSIGHT_API_LLM_MODEL = defaultLlm.modelAlias;
                    # The openai provider requires this populated even when the
                    # backend ignores it; llama-server runs with no API key set.
                    # Upstream's own example uses the literal "not-needed".
                    HINDSIGHT_API_LLM_API_KEY = "not-needed";

                    # Not a tuning preference — a 15.5-point swing on upstream's
                    # own retain leaderboard (v0.9.2, the version pinned here):
                    # gpt-oss 20B at LOW ranks 4th at 57.8 and 5.1s end to end,
                    # the same model at MEDIUM ranks 14th at 42.3 and 55.2s.
                    # Leaving this unset sends no reasoning parameter at all, and
                    # gpt-oss then runs at its own default — which is medium.
                    HINDSIGHT_API_LLM_REASONING_EFFORT = "low";

                    # Upstream default is false: a retain that hit extraction
                    # errors is reported 'completed' and the dropped facts are
                    # silently unreachable by recall. That is precisely the
                    # failure this deployment exists to stop happening to the
                    # law corpus, so failures are made loud.
                    HINDSIGHT_API_FAIL_ON_EXTRACTION_ERRORS = "true";

                    # ★★★ MAKE BACKPRESSURE LAND WHERE WAITING IS FREE.
                    # Work can wait in three places and only two of them are free:
                    #   1. the DURABLE TASK QUEUE in postgres — observable, survives
                    #      a restart, no clock running. Bounded by WORKER_MAX_SLOTS.
                    #   2. the CLIENT SEMAPHORE — a call blocks before the request is
                    #      issued, so no timeout is ticking. Bounded by LLM_MAX_CONCURRENT.
                    #   3. llama-server's own SOCKET QUEUE — a request that is waiting
                    #      for a slot is already inside its timeout. This one is NOT free.
                    #
                    # Measured 2026-09-01, all three unset and therefore at upstream
                    # defaults: WORKER_MAX_SLOTS 10 (8 shared + 2 reserved) and
                    # LLM_MAX_CONCURRENT 32, against a real serving capacity of
                    # N_PARALLEL 2 x 3 replicas = 6. A backfill put 124 tasks in the
                    # queue, 8 claimed slots at once, the surplus queued in (3), each
                    # burned the 120s LLM_TIMEOUT while waiting, failed with
                    # APITimeoutError, and retried — which re-queued them. Observed:
                    # `slots=9/10 | shared=8/8(avail=0)`, one call at 422.859s, a
                    # consolidation stuck 3298s at attempt 3/4, 5 failed retains.
                    # That is a retry storm, not a queue draining.
                    #
                    # So the cap is DERIVED from what actually serves, and the surplus
                    # is pushed back into (1) and (2) where it waits for free.
                    HINDSIGHT_API_LLM_MAX_CONCURRENT = toString defaultLlm.slots;

                    # In-flight tasks per worker. Held at the serving capacity for the
                    # same reason: a claimed slot whose LLM call cannot be served is a
                    # task holding a slot AND a socket, while an unclaimed task costs a
                    # postgres row. Reserved consolidation slots come out of this total,
                    # so this is the ceiling on everything, not just retain.
                    HINDSIGHT_API_WORKER_MAX_SLOTS = toString defaultLlm.slots;

                    # A slow call must COMPLETE, not fail and retry. Upstream default is
                    # 120s; a real retain_extract_facts call measured 422.859s on this
                    # hardware at 7642 input tokens. With concurrency now matched to
                    # capacity a request should not queue at llama-server at all, but a
                    # long chunk on a cold slot still exceeds two minutes, and failing
                    # it converts one slow extraction into four (WORKER_MAX_RETRIES=3).
                    HINDSIGHT_API_LLM_TIMEOUT = "900";

                    # Per-bank tokens (hindsight-write-gate.py). The loader
                    # passes every HINDSIGHT_API_OPERATION_VALIDATOR_* variable to
                    # the gate as config. A listed bank with a missing or empty
                    # token file, or a bad admin digest, stops the server at startup.
                    PYTHONPATH = gateDir;
                    HINDSIGHT_API_OPERATION_VALIDATOR_EXTENSION = "hindsight_write_gate:WriteGate";
                    HINDSIGHT_API_OPERATION_VALIDATOR_BANKS = builtins.toJSON (
                      lib.mapAttrs (_: b: { gate_reads = b.gateReads; }) gatedBanks
                    );
                    HINDSIGHT_API_OPERATION_VALIDATOR_TOKENS_DIR = tokensDir;
                    HINDSIGHT_API_OPERATION_VALIDATOR_ADMIN_SHA256_FILE = "${adminDir}/sha256";

                    # Document import (POST …/document-transfer) calls no validator
                    # hook when the bank already exists, so the gate cannot see it.
                    # Upstream defaults it on.
                    HINDSIGHT_API_ENABLE_DOCUMENT_IMPORT_API = "false";
                  }
                  # Per-operation override for retain, emitted ONLY when it
                  # actually differs from the default. Pointing both at one
                  # instance and still emitting these would be four env vars
                  # restating the global config — and a reader would reasonably
                  # infer a split that isn't there.
                  // lib.optionalAttrs (settings.retainLlmInstance != settings.defaultLlmInstance) {
                    HINDSIGHT_API_RETAIN_LLM_PROVIDER = "openai";
                    HINDSIGHT_API_RETAIN_LLM_BASE_URL = retainLlm.url;
                    HINDSIGHT_API_RETAIN_LLM_MODEL = retainLlm.modelAlias;
                    HINDSIGHT_API_RETAIN_LLM_API_KEY = "not-needed";

                    # ONE. Not derived like the read path's cap, because an external
                    # endpoint's capacity is not ours to compute — it is stated at the
                    # externalLlms entry, and ninfer's says maxConcurrency=1 with hermes
                    # as primary tenant. Measured besides: ninfer batches DECODE well but
                    # SERIALIZES PREFILL (four 30K-token prompts finishing 72s apart),
                    # and retain is prefill-bound — 5252 prompt tokens against 1520 out.
                    # So concurrency above 1 inflates each request's wall time without
                    # adding throughput, and every extra second is spent inside the
                    # timeout.
                    HINDSIGHT_API_RETAIN_LLM_MAX_CONCURRENT = "2";

                    # ★★★ ninfer CANNOT SERVE RETAIN. Trialled and REVERTED 2026-09-02:
                    #     HTTP 400 response_format_not_supported —
                    #     "only response_format {type:text} is supported"
                    # Fact extraction requests STRUCTURED OUTPUT; ninfer accepts text only,
                    # so every retain failed 4/4 attempts. This is a capability gap, not a
                    # tuning one — no timeout, concurrency or token budget reaches it.
                    # ★ THE TRIAL THAT SAID OTHERWISE MEASURED THE WRONG PREDICATE. A hand-
                    # built chat completion with the same mission and a real 12000-char chunk
                    # returned in 13.6s at 445 tok/s against llama-cpp's 422.9s — true, and
                    # irrelevant, because it omitted the response_format hindsight sends.
                    # A probe must issue the REQUEST SHAPE THE CALLER USES, not the prompt.
                    # ⇒ Re-test with a response_format request before proposing this again.
                    #
                    # ★ THE BACKFILL ERA IS OVER (2026-09-02) — retain is back in-cluster and
                    # this whole block is DORMANT: it emits only while retainLlmInstance differs
                    # from defaultLlmInstance. Kept because the era will recur, and because what
                    # it records is the reason the split was worth making. The corpus it built:
                    # 101 sessions across two hosts, 239 law/ADR documents re-extracted, 88
                    # handoff revisions, ~6100 episode facts at 98.4% labelled, zero failures.
                    #
                    # ⇒ RESOLVED by cortex-cuda running llama-cpp with the SAME MODEL on
                    # :8080 beside ninfer on :8081. llama-cpp constrains decoding to a
                    # schema, so json_schema and json_object both return 200 (measured
                    # 2026-09-02, 1.8s for 4563 prompt tokens). retainLlmInstance points
                    # there; the model is unchanged, so this moves WHERE extraction runs
                    # and not what the corpus was extracted by.
                    #
                    # Concurrency 2, not 1: this is llama-cpp at its default
                    # parallelSlots, not ninfer's stated maxConcurrency=1.
                    #
                    # Retain runs OFF-CLUSTER on a workstation GPU, which is the
                    # point: the write path stops sharing a queue with recall. Measured
                    # 2026-09-01 on identical work — one real 12000-char chunk under the
                    # live episode mission:
                    #     llama-cpp gpt-oss-20b   422.859s   (7642 in / 67 out)
                    #     ninfer    qwen3.8-27b    13.6s     (5252 in / 800 out, 445 tok/s)
                    # ★ THE STANDING CAVEAT AT THE externalLlms ENTRY STILL APPLIES: this
                    # is a dev workstation that queues behind interactive work and stops
                    # when it reboots — "suitable for batch corpus work, not the live
                    # path". archiveHook makes SessionEnd a live path, so that risk is
                    # accepted rather than absent. It is bounded: the archiver fails OPEN
                    # and hindsight-backfill's completeness check republishes anything
                    # left short. Revisit when the backfill era ends.
                  };

                  probes = {
                    # /health is the readiness endpoint; /health/live the
                    # liveness one (upstream chart's split).
                    liveness = {
                      enabled = true;
                      type = "HTTP";
                      path = "/health/live";
                      inherit port;
                    };
                    readiness = {
                      enabled = true;
                      type = "HTTP";
                      path = "/health";
                      inherit port;
                    };
                    # First boot downloads the embedder + reranker from
                    # HuggingFace into the (empty) model-cache PVC before the
                    # API serves anything; 10 minutes of headroom keeps the
                    # liveness probe from killing the pod mid-download.
                    startup = {
                      enabled = true;
                      custom = true;
                      spec = {
                        httpGet = {
                          path = "/health";
                          inherit port;
                        };
                        periodSeconds = 10;
                        failureThreshold = 60;
                      };
                    };
                  };

                  ports = [
                    {
                      name = "http";
                      containerPort = port;
                    }
                  ];

                  # ~2Gi resident under load with both local models in-process
                  # (upstream's hardware table); the ceiling leaves room for a
                  # large retain, whose in-flight extraction state is bounded by
                  # HINDSIGHT_API_RETAIN_MEMORY_BUDGET_MB (default 128).
                  resources = {
                    requests = {
                      cpu = "200m";
                      memory = "1Gi";
                    };
                    limits = {
                      cpu = "2000m";
                      memory = "4Gi";
                    };
                  };
                };
              };

              service.main = {
                controller = "main";
                # Pin to `hindsight`: bjw-s suffixes every service with its
                # identifier once a controller owns >1 service, so adding the
                # LoadBalancer below would otherwise rename this to
                # `hindsight-main` and move the in-cluster address under every
                # existing consumer. Same reason shoko.nix pins its own.
                forceRename = "hindsight";
                ports.http.port = port;
              };

              # Private-network reach on a kubernetes-loadbalancers address,
              # BGP-advertised to the LAN and not internet-routable — the shoko
              # idiom. This is how workstations and off-cluster agents reach the
              # bank without a public HTTPRoute and without the OIDC gateway,
              # which headless MCP clients cannot complete anyway.
              #
              # NOTE: anything on the LAN that can route here reads and writes every
              # bank outside gatedBanks and reads the ones without gateReads; the
              # rest needs the bank's token. The CiliumNetworkPolicies below admit
              # the callers.
              service.internal = {
                controller = "main";
                type = "LoadBalancer";
                externalTrafficPolicy = "Local";
                annotations."lbipam.cilium.io/ips" = cluster.getAssignment "hindsight-internal";
                ports.http.port = port;
              };

              persistence = {
                # HuggingFace cache for the local embedder (~130 MB) and
                # reranker (~90 MB), so they are fetched once rather than on
                # every pod start. Upstream mounts the cache at this path.
                model-cache = {
                  type = "persistentVolumeClaim";
                  accessMode = "ReadWriteOnce";
                  size = "5Gi";
                  storageClass = "longhorn";
                  globalMounts = [ { path = "/home/hindsight/.cache"; } ];
                };

                write-gate = {
                  type = "configMap";
                  identifier = "write-gate";
                  advancedMounts.main.main = [
                    {
                      path = "${gateDir}/hindsight_write_gate.py";
                      subPath = "hindsight_write_gate.py";
                      readOnly = true;
                    }
                  ];
                };

                # One file per gated bank. 0440 with the pod's fsGroup 1000 makes
                # them readable by the image's uid 1000 and no one else in the pod.
                write-tokens = {
                  type = "secret";
                  name = "hindsight-write-tokens";
                  defaultMode = 288; # 0440
                  advancedMounts.main.main = [
                    {
                      path = tokensDir;
                      readOnly = true;
                    }
                  ];
                };

                # The admin token's SHA-256 only; the token is the CP's.
                admin-digest = {
                  type = "secret";
                  name = "hindsight-cp-admin-token-sha256";
                  defaultMode = 288; # 0440
                  advancedMounts.main.main = [
                    {
                      path = adminDir;
                      readOnly = true;
                    }
                  ];
                };
              };

              configMaps.write-gate.data."hindsight_write_gate.py" = builtins.readFile ./hindsight-write-gate.py;
            };
          };

          # Control plane — the Next.js UI over the dataplane API. Separate
          # release rather than a second controller in the one above: it is a
          # different image on a different lifecycle, holds no state, wants no
          # PVC, and should be able to restart without touching the API.
          #
          # It exposes no metrics (upstream: "the control plane (Next.js) does
          # not expose metrics"), so it gets no PodMonitor, and its probes are
          # tcpSocket because it serves no /health.
          helm.releases.hindsight-cp = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers.main = {
                type = "deployment";
                replicas = 1;
                pod.labels."den.ai/component" = "hindsight-cp";

                containers.main = {
                  image = {
                    inherit (images."vectorize-io/hindsight-control-plane") repository digest;
                  };

                  env = {
                    NODE_ENV = "production";
                    HINDSIGHT_CP_HOSTNAME = "0.0.0.0";
                    HINDSIGHT_CP_PORT = toString cpPort;
                    # In-cluster, via the pinned service name.
                    HINDSIGHT_CP_DATAPLANE_API_URL = "http://hindsight.ai.svc.cluster.local:${toString port}";
                    # The admin token: the CP's server-side API routes send it as
                    # `Authorization: Bearer` on every dataplane call
                    # (src/lib/hindsight-client.ts at the pinned version), so a
                    # user the gateway admits has full access with no token of
                    # their own. HINDSIGHT_CP_ACCESS_KEY stays unset: the gateway's
                    # admin-only OIDC is the authorization.
                    HINDSIGHT_CP_DATAPLANE_API_KEY.valueFrom.secretKeyRef = {
                      name = "hindsight-cp-admin-token";
                      key = "token";
                    };
                  };

                  probes = {
                    liveness = {
                      enabled = true;
                      custom = true;
                      spec = {
                        tcpSocket.port = cpPort;
                        initialDelaySeconds = 30;
                        periodSeconds = 10;
                      };
                    };
                    readiness = {
                      enabled = true;
                      custom = true;
                      spec = {
                        tcpSocket.port = cpPort;
                        initialDelaySeconds = 10;
                        periodSeconds = 5;
                      };
                    };
                  };

                  ports = [
                    {
                      name = "http";
                      containerPort = cpPort;
                    }
                  ];

                  resources = {
                    requests = {
                      cpu = "50m";
                      memory = "256Mi";
                    };
                    limits = {
                      cpu = "1000m";
                      memory = "1Gi";
                    };
                  };
                };
              };

              # ClusterIP only. The CP holds the admin token, so its one way in
              # is the gateway's admin-only route below; no LoadBalancer, no
              # NodePort.
              service.main = {
                controller = "main";
                forceRename = "hindsight-cp";
                ports.http.port = cpPort;
              };
            };
          };

          # Raw PodMonitor: no typed accessor without a kube-prometheus-stack
          # CRDs bridge, so author it directly (mirrors the monitoring aspect).
          # The API serves Prometheus format at /metrics on its own port.
          objects = [
            {
              apiVersion = "monitoring.coreos.com/v1";
              kind = "PodMonitor";
              metadata = {
                name = "hindsight";
                namespace = "ai";
              };
              spec = {
                selector.matchLabels."app.kubernetes.io/name" = "hindsight";
                podMetricsEndpoints = [
                  {
                    port = "http";
                    path = "/metrics";
                    interval = "30s";
                    # Default instance is the ephemeral pod IP:port, which
                    # churns on every restart; pin it to the stable app name.
                    relabelings = [
                      {
                        sourceLabels = [ "__meta_kubernetes_pod_label_app_kubernetes_io_name" ];
                        targetLabel = "instance";
                      }
                    ];
                  }
                ];
              };
            }
          ];

          # The nixidy objectTransform rewrites each Secret → SopsSecret; each value
          # is a sops ref resolved at render time. hindsight-write-tokens holds one
          # key per gated bank (the name predates read gating and is kept so the
          # deployed object is not replaced).
          resources.secrets = {
            hindsight-write-tokens = {
              type = "Opaque";
              stringData = lib.genAttrs gatedBankNames (bank: config.age.secrets.${tokenSecret bank}.sopsRef);
            };
            hindsight-cp-admin-token-sha256 = {
              type = "Opaque";
              stringData.sha256 = config.age.secrets.hindsight-cp-admin-token-sha256.sopsRef;
            };
            hindsight-cp-admin-token = {
              type = "Opaque";
              stringData.token = config.age.secrets.hindsight-cp-admin-token.sopsRef;
            };
            hindsight-oidc-client-secret = {
              type = "Opaque";
              stringData.client-secret = config.age.secrets.hindsight-oidc-client-secret.sopsRef;
            };
          };

          # The control-plane UI, behind the gateway's kanidm OIDC. kanidm maps only
          # `admins` to the `hindsight` client (kanidm.nix), so no one else can
          # obtain a session; the gateway's admission is the authorization.
          resources.httpRoutes.hindsight.spec = {
            hostnames = [ (cluster.domainFor "hindsight") ];
            parentRefs = [
              {
                name = "default-gateway";
                namespace = "gateways";
                sectionName = "${cluster.domainForResource "hindsight"}-https";
              }
            ];
            rules = [
              {
                backendRefs = [
                  {
                    name = "hindsight-cp";
                    port = cpPort;
                  }
                ];
              }
            ];
          };

          resources.securityPolicies."hindsight-oidc".spec = {
            targetRefs = [
              {
                group = "gateway.networking.k8s.io";
                kind = "HTTPRoute";
                name = "hindsight";
              }
            ];
            oidc = {
              provider = cluster.secrets.oidcProviderFor "hindsight";
              clientID = "hindsight";
              clientSecret.name = "hindsight-oidc-client-secret";
              scopes = [
                "email"
                "openid"
                "profile"
              ];
            };
          };

          # In-cluster egress (hindsight-pg, kube-dns) is already covered by the
          # clusterwide allow-internal-egress policy (cilium.nix), so only the
          # off-cluster paths and the ingress are enumerated here.
          resources.ciliumNetworkPolicies = {
            # Declaring any ingress rule flips this pod to ingress default-deny.
            # Prometheus is the only legitimate caller in this wave; the gateway
            # is added when the route is.
            allow-metrics-ingress-hindsight.spec = {
              description = "Allow Prometheus to scrape hindsight (8888).";
              endpointSelector.matchLabels."app.kubernetes.io/name" = "hindsight";
              ingress = [
                {
                  fromEndpoints = [
                    {
                      matchLabels = {
                        "k8s:io.kubernetes.pod.namespace" = "monitoring";
                        "app.kubernetes.io/name" = "prometheus";
                      };
                    }
                  ];
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

            # The control plane reaches the API from a POD address (172.20/16),
            # which the LAN rule below does not cover — without this the
            # ingress default-deny silently drops it.
            # Namespace-pinned: the app label alone would admit a pod carrying it
            # in any namespace.
            allow-cp-ingress-hindsight.spec = {
              description = "Allow the hindsight control plane to reach the dataplane API (8888).";
              endpointSelector.matchLabels."app.kubernetes.io/name" = "hindsight";
              ingress = [
                {
                  fromEndpoints = [
                    {
                      matchLabels = {
                        "k8s:io.kubernetes.pod.namespace" = "ai";
                        "app.kubernetes.io/name" = "hindsight-cp";
                      };
                    }
                  ];
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

            # genie tier-1 recalls from the genie banks and may do nothing else
            # here. Selected by namespace and service account, which Cilium sets
            # from the pod spec and a pod cannot claim (see model-egress.nix). The
            # HTTP rule sends this port through Envoy, which answers 403 to any
            # other method or path from this identity, whatever token it holds.
            allow-genie-tier1-recall-hindsight.spec = {
              description = "Allow genie tier-1 to recall from the genie banks on 8888 (HTTP rule: recall and the read-only GETs its client makes).";
              endpointSelector.matchLabels."app.kubernetes.io/name" = "hindsight";
              ingress = [
                {
                  fromEndpoints = [
                    {
                      matchLabels = {
                        "k8s:io.kubernetes.pod.namespace" = "genie";
                        "k8s:io.cilium.k8s.policy.serviceaccount" = "genie-tier1";
                      };
                    }
                  ];
                  toPorts = [
                    {
                      ports = [
                        {
                          port = toString port;
                          protocol = "TCP";
                        }
                      ];
                      rules.http = [
                        {
                          method = "POST";
                          path = "/v1/default/banks/(genie|genie-memory)/memories/recall";
                        }
                        {
                          method = "GET";
                          path = "/v1/default/banks/(genie|genie-memory)/(profile|config|memories/list)";
                        }
                      ];
                    }
                  ];
                }
              ];
            };

            # The control plane's only ingress: the gateway's proxies, which admit
            # a request only after the admin-only OIDC. Being the only rule, it
            # puts the CP in ingress default-deny for everything else.
            allow-gateway-ingress-hindsight-cp.spec = {
              description = "Allow only Envoy Gateway proxies to reach the hindsight control plane UI (3000).";
              endpointSelector.matchLabels."app.kubernetes.io/name" = "hindsight-cp";
              ingress = [
                {
                  fromEndpoints = [
                    { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; }
                  ];
                  toPorts = [
                    {
                      ports = [
                        {
                          port = toString cpPort;
                          protocol = "TCP";
                        }
                      ];
                    }
                  ];
                }
              ];
            };

            # Off-cluster LAN callers (workstations, uplink) reach the bank over
            # the internal LoadBalancer above, bypassing the gateway. The whole
            # private 10/8 range rather than a per-host pin: it is portable, the
            # LB address is RFC1918 and not internet-routable, and it covers both
            # the externalTrafficPolicy=Local source (the caller's real IP) and
            # any node SNAT. Mirrors allow-lan-ingress-shoko.
            allow-lan-ingress-hindsight.spec = {
              description = "Allow private-LAN clients to reach hindsight on 8888 over the internal LoadBalancer.";
              endpointSelector.matchLabels."app.kubernetes.io/name" = "hindsight";
              ingress = [
                {
                  fromCIDR = [ "10.0.0.0/8" ];
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

            # In-cluster LLM traffic rides the clusterwide allow-internal-egress
            # policy. OFF-cluster endpoints do not: declaring any egress rule
            # puts this pod in egress default-deny, so each external endpoint in
            # use needs naming or Cilium silently drops it. Generated only for
            # endpoints actually referenced by the settings above.
          }
          // lib.optionalAttrs (usedExternals != [ ]) {
            allow-external-llm-egress-hindsight.spec = {
              description = "Allow hindsight to reach off-cluster LLM endpoints (e.g. llama-cpp on cortex-cuda).";
              endpointSelector.matchLabels."app.kubernetes.io/name" = "hindsight";
              egress = map (e: {
                toCIDR = [ e.cidr ];
                toPorts = [
                  {
                    ports = [
                      {
                        port = toString e.port;
                        protocol = "TCP";
                      }
                    ];
                  }
                ];
              }) usedExternals;
            };
          }
          // {
            # World egress purely to populate the model cache on first boot.
            # Once the PVC is warm this is dead weight — a candidate to drop, or
            # to replace with an image that bakes the two models in.
            allow-huggingface-egress-hindsight.spec = {
              description = "Allow hindsight to fetch the local embedder/reranker from HuggingFace on first boot.";
              endpointSelector.matchLabels."app.kubernetes.io/name" = "hindsight";
              egress = [
                {
                  toEntities = [ "world" ];
                  toPorts = [
                    {
                      ports = [
                        {
                          port = "443";
                          protocol = "TCP";
                        }
                      ];
                    }
                  ];
                }
              ];
            };
          };
        };
      };
  };
}
