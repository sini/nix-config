# Hindsight memory aspect — kubernetes backend + harness wiring

**Date:** 2026-08-28 · **Status:** DRAFT — for the next phase design spike
**Scope:** two nix-config aspects (kubernetes backend service + CNPG database, MCP client
wiring) + the trial protocol that decides adoption. Evaluation basis: the 2026-08-28 owner
sitting (this repo's tracker carries the bead; upstream facts below were read from
`vectorize-io/hindsight` at HEAD that day). Amended same day: backend retargeted from a
single-host uplink service to the cluster (owner direction, radarr/CNPG precedent).

## Problem

The memory corpus has one deterministically delivered layer — the `MEMORY.md` index — and it is
over capacity: 42 lines against the 40-line cap [MEASURED 2026-08-28: `wc -l ~/.claude/memory/MEMORY.md`].
Everything past the index is delivered at agent discretion: linked bodies are not read reliably
[RELAYED owner], law was stripped/archived purely to fit the cap [RELAYED owner], and removing
one redundant delivery channel (laws banked as beads, read at boot) measurably caused missed
laws [RELAYED owner]. Capacity-forced deletion of valid law is the project's core defect class —
something vanishes and nothing says so — enforced by the delivery channel itself.

Cross-harness: syncthing replicates the corpus across machines but gives hermes-agent and
Antigravity no read path into it. The current marker/frontmatter system has no qualifications —
zero benchmarks, zero measured delivery rate. Hindsight has LongMemEval SOTA with independent
reproduction (Virginia Tech Sanghani Center, The Washington Post) [MEASURED: upstream README].

**What this spec does NOT change:** the pushed tier. `MEMORY.md` + SessionStart injection stay
canonical and unchanged. Hindsight is added as a *derived read index* over the same corpus.
Files remain the source of truth: greppable, versioned, syncthing-replicated, and the fallback
read path when the service is down. The bank is rebuildable from the corpus by construction.

## Mechanism

### 1. Backend — `den.aspects.kubernetes.services.ai.hindsight`

New file `modules/den/aspects/kubernetes/services/ai/hindsight.nix` (radarr idiom: app-template
helm release, digest-pinned image, CNPG Postgres, Cilium policies, PodMonitor). The cluster
replaces uplink as the server host. The original uplink rationale — 128 GB RAM — was only ever
about running the extraction MODEL there; the hindsight server itself sits around 2 GB under
load [MEASURED: upstream hardware table] and calls its LLM over HTTP, so **server placement and
extraction placement are independent decisions**.

- **Runtime:** the full image `ghcr.io/vectorize-io/hindsight` (bundles the local embedder
  `BAAI/bge-small-en-v1.5` ~130 MB and reranker `cross-encoder/ms-marco-MiniLM-L-6-v2` ~90 MB;
  CPU-only is fine at this traffic), digest-pinned through the oci-image-updater catalog like
  every other cluster image — which retires the draft's pin-by-hand requirement. Set
  `HINDSIGHT_API_WORKER_ID` explicitly: deployment pod names churn, and upstream documents that
  in-flight tasks park under the dead worker identity otherwise.
- **Database:** CNPG — the operator already runs (`media-pg` precedent). REQUIRES pgvector in
  the postgres image; whether the in-use CNPG image carries it decides shared-cluster vs
  own-cluster (Open Question 1, blocking, verify first).
- **Persistence:** CNPG PVCs for data; one PVC for the HuggingFace model cache so the
  embedder/reranker are not re-fetched per pod start (delivery shape is Open Question 6).
- **Network:** Cilium policies per the radarr shape — ingress from the gateway and Prometheus;
  egress to kube-dns, the CNPG cluster, and the extraction endpoint only. Agent-facing
  exposure via an HTTPRoute + API token; gateway OIDC does not fit headless agent clients
  (Open Question 2).
- **Observability, free with the idiom:** PodMonitor + upstream's metrics. Wire an alert on
  `hindsight.retain.documents.total{outcome!="success"}` — retain failure and the documented
  zero-fact outcome MUST be loud; the async write path's failure mode is a silent stall.

**Extraction LLM** (write path only — recall needs no LLM): `HINDSIGHT_API_LLM_PROVIDER=openai`
with base URL/model as settings. **Default: uplink's ollama** (`services.ai.ollama`, already in
uplink's includes) — always resident, and retain is async/background so throughput is not
latency-critical. The fast path — cortex-cuda ninfer at ~100 tok/s — stays a documented
alternative, NOT the default, on two measured facts from its own aspect: `autoStart = false`
(GPU-swaps with llama-cpp/ollama, so only conditionally resident) and `maxConcurrency = 1` with
the KV pool sized as a single request's entitlement, so retain traffic queues against hermes,
cortex-cuda's primary tenant. At `den-law` volume (explicit retain, a few small documents a
day) both caveats are negligible and either backend clears upstream's recommended extractor
class (`gpt-oss-20b` — "Hindsight doesn't need a smart model"); the choice matters only at
hermes-auto-capture volume, which is precisely when contention with hermes bites hardest.
Revisit there, not here.

### 2. Corpus seed + sync (on uplink, beside the corpus replica)

- uplink is the syncthing hub, so the `~/.claude/memory/` replica is already local there. A
  systemd path/timer unit on uplink retains changed files into bank **`den-law`** over the
  cluster API: `document_id` = the memory's slug, tags from frontmatter `type:`. Co-location
  with the SERVER was always convenience; co-location with the CORPUS is the requirement, and
  that stays on uplink. Re-retain of a changed file must REPLACE, not duplicate — the exact
  documents-API call is Open Question 3 and blocks the sync unit, not the trial (the trial
  seeds once, by hand or script).
- **Explicit retain only.** No transcript auto-retain anywhere, in any harness — the upstream
  plugin's `Stop`-hook capture is excluded by construction (the aspect wires MCP only). This is
  the standing ruling from the 2026-08-28 evaluation: curation is the write path's property;
  auto-capture of adversarial transcripts would bank seeded defects and self-assessment prose
  as facts.
- **Seed set:** the current corpus PLUS memories previously stripped/archived purely for
  capacity (owner supplies the reinstatement list — a curation pass, not a bulk import of
  `archive/memory/`).
- **Precondition — register scrub before seeding.** Boot surfaces carry first-person failure
  narratives (HANDOFF 89 line 1 headline; "MY self-correction was ALSO WRONG"; provenance-fused
  index lines). Recall is similarity-keyed, so seeding that register builds a retriever that
  serves failure narratives at failure moments. The two-record split (law file ⊥ ledger,
  ADR-0021's own pattern) applies to `MEMORY.md` and the handoff BEFORE the corpus is seeded.
  Separate work unit; blocks seeding, not deployment.
- **Seeding audit (armed).** Upstream documents that extraction is non-deterministic and that a
  document yielding zero facts is *silently unreachable by recall* while the retain reports
  success — the silent-vanish class. After seeding: `GET /documents` filtered
  `memory_unit_count == 0` MUST be empty across the corpus, with a positive control (one
  seeded nonsense-sentinel document expected to sit at 0, proving the probe can see zeros).
  Any corpus file at 0 is reprocessed (`POST .../documents/{id}/reprocess`) until non-zero or
  escalated.

### 3. Client aspect — `den.aspects.applications.dev.ai.mcp.hindsight`

New file `modules/den/aspects/applications/dev/ai/mcp/hindsight.nix` (serena idiom):

- `agent-extensions` of type `mcp`: the per-bank endpoint `https://<cluster domain>/mcp/den-law/`
  into claude-code, with the hostname derived from the cluster's domain machinery
  (`cluster.domainFor`), never hardcoded. Antigravity and hermes consume the same endpoint in
  their own aspect files (hermes.nix already derives its ninfer endpoint the same way; REST for
  hermes if its loop prefers it).
- The upstream claude-code plugin's auto-hooks (`UserPromptSubmit` recall injection, `Stop`
  retain) are NOT installed. A `recallHook.enable` setting exists, **default false**, flipped
  only in trial phase 2 and only for claude-code.
- Read-only posture for the trial: agents query `den-law` via MCP recall; nothing writes to it
  except the seed/sync path.

### 4. Trial protocol (the spike's checklist)

1. Register scrub lands (precondition).
2. Deploy backend, seed `den-law`, run the seeding audit (O2).
3. **Replay oracle (O3), before any session wiring:** collect the known missed-law incidents
   as prompts, plus no-law-applies control prompts. Requirement, stated before the run per gate
   law: each missed-law prompt's applicable memory appears in the recall result; controls
   surface no law-class memory. The verdict is a table the owner reads ONCE (person-oracle).
4. Phase 2, only on a green O3: enable `recallHook` for claude-code in this repo and work
   normally for a bounded period; compare missed-law incidence.
5. Degradation + persistence checks (O1, O4) at any point after deploy.

## Acceptance oracles

Red/green declared here, before anything runs.

- **O1 — service + persistence.** Readiness green after deploy; then delete the pod AND reboot
  its node — health returns green and every seeded document is still present (CNPG + PVC
  persistence, not pod-local state). RED: non-200 after recovery, or any seeded document
  absent.
- **O2 — seeding audit.** Zero corpus documents with `memory_unit_count == 0`; the sentinel
  control reads 0. RED: any corpus file at 0 after reprocess, or a control that cannot show a
  zero.
- **O3 — replay.** Every known missed-law prompt recalls its applicable memory; controls
  clean. Person-oracle: one owner reading of the table, no manufactured metric.
- **O4 — cross-harness round-trip.** One recall of the same seeded sentinel memory from each
  of: claude-code (MCP), Antigravity (MCP), hermes-agent (REST/MCP). RED: any harness cannot
  retrieve it.
- **O5 — no-auto-capture invariant.** After a full working session with the aspect enabled,
  the bank's document count equals the seeded count. RED: the count grew — something captured
  a transcript.

## Open questions

1. **CNPG topology (blocking — verify first).** Database on an existing CNPG cluster vs its
   own small cluster. Decided by whether the in-use CNPG postgres image carries pgvector; if
   not, hindsight needs its own cluster on a pgvector-capable image. Rec: own small cluster
   regardless — the law corpus should not share a failure domain with the media stack.
2. **Exposure.** HTTPRoute + API token at the gateway (rec — one mechanism for workstations,
   uplink's sync unit, and hermes) vs cluster-internal only with tailnet reach. Gateway OIDC
   is not usable by headless agent clients either way.
3. **Update semantics.** Verify the documents-API call for re-retaining a changed file under
   the same `document_id` replaces rather than duplicates. Blocks the sync unit only.
4. **Memory Defense** (upstream's secret/PII scan on retain, 45 patterns). Rec: ON — the
   corpus should never contain secrets, so its only effect is catching a mistake.
5. **Bank layout.** `den-law` is shared-read for all harnesses. hermes-agent's own working
   memory (auto-capture appropriate THERE) is a separate bank in a separate work unit — out of
   scope here so its write posture can differ without touching this one. That is also where
   the cortex-cuda extraction default gets revisited.
6. **HF model cache delivery.** Warm the PVC on first boot with temporary world egress to
   HuggingFace, vs baking the two models into a derived image (closed egress, bigger image).
   Rec: warm-once PVC for the spike; revisit at adoption.
