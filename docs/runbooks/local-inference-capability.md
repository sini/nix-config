# Runbook: Local inference capability — measuring the fleet

**Hosts:** blade · axon-01..03 · uplink · cortex-cuda (reference)
**Validated:** _not yet run_

Decide, by measurement, which hosts can carry which inference role. Two
questions are open and they are not the same question:

1. Can any host besides `cortex-cuda` serve an **interactive agent at 160k
   context**? ("slow but correct" is acceptable; 50k is not.)
2. Is **many small models in parallel** a better use of the fleet than one
   large model — for the background class (Hindsight retain/consolidate,
   memory extraction, `auxiliary.background_review`, embeddings)?

**Default posture: do nothing.** `cortex-cuda` already serves the core agent at
~200k and ~96 tok/s. Nothing here is worth deploying unless it clears the
accept threshold written down *before* the run.

---

## Inventory

Measured from `hosts/<name>/facter.json` unless marked otherwise.

| Host | CPU | RAM | Accelerator | Notes |
|---|---|---|---|---|
| `cortex-cuda` | — | — | RTX 3090 Ti 24 GiB, 1008 GB/s | **Reference.** Measured in `services/ai/ninfer.nix`: 96.2 tok/s decode, 1121 tok/s prefill, 15,523 tok prefilled in 13.66 s |
| `blade` | i9-13950HX, 8P+16E (24c/32t), **no AVX-512** | **2×48 = 96 GiB** DDR5-5600 ⚠ | RTX 4090 Laptop, 16 GiB, ~576 GB/s | Razer notebook. Thermally constrained. ⚠ **Pin to P-cores (`taskset -c 0-15` or `-t 16`)** to avoid low-bandwidth E-core scheduling |
| `axon-01..03` | Ryzen 9 7940HS, 8c/16t, **AVX-512 + BF16** | 2×32 = 64 GiB DDR5-5600 | Radeon 780M (gfx1103) | Mobile 35–54 W. Prod k3s nodes. TB mesh @ 20 Gbps |
| `uplink` | Ryzen 9 5950X, 16c/32t, **no AVX-512** | 4×32 = 128 GiB DDR4 **@ 2666?** ⚠ | Arc A310, ~4 GiB (not an offload target) | Only host with >64 GiB in one address space |
| `bitstream` | Ryzen 5 6600H, 6c/12t | 2×8 = 16 GiB ⚠ | Radeon 660M | **Excluded** — too small |

⚠ **Stale facts, fix before trusting a build:**

- `hosts/blade/facter.json` records 2×16 = 32 GiB. Actual is **2×48 = 96 GiB**;
  the 2×16 pair moved to `bitstream`. Both files need regenerating.
- `hosts/uplink/facter.json` SMBIOS reports **2666 MT/s** for a 3600-rated kit
  (F4-3600C18-32GTZR). Four dual-rank DDR4 DIMMs on a Zen 3 IMC routinely fall
  back. 2666 vs 3600 is a 35% swing in the one number that governs decode —
  establish it with `dmidecode` before any uplink estimate is quoted.

```bash
sudo nixos-facter -o hosts/<name>/facter.json    # after any RAM change
sudo dmidecode -t 17 | grep -E 'Speed|Rank|Size'
```

---

## Why depth is the whole experiment

At 160k the dominant decode term is the **KV cache**, not the weights:

```
tg ≈ BW_eff / (active_weight_bytes + kv_bytes_at_depth)
```

For a small-active MoE this inverts the usual intuition — a 30B-A3B reads
~1.9 GB of weights but ~8 GB of q8 KV at 160k, so the MoE trick that makes CPU
inference viable at `d=0` largely stops working at our depth. **A benchmark at
`d=0` is measuring a different machine than the one we run agents on.** Every
throughput cell in this runbook carries a depth.

Corollary for `blade`: 16 GiB of VRAM cannot hold a large MoE, but it can hold
the KV cache — the term that actually costs — while expert tensors stream from
96 GiB of DDR5. That placement, not the GPU's size, is the hypothesis.

---

## Hypotheses

Written before the run. A hypothesis with no stated reject condition is not
being tested.

**H1 — `blade` can serve a 160k interactive agent.**
Accept if *all*: warm-delta TTFT ≤ 60 s at 160k depth · sustained decode
≥ 15 tok/s measured on the **thermal tail** (rep 5 of 5, not rep 1) · cold 160k
prefill ≤ 15 min · needle-at-160k clean at the chosen KV quant.
Reject → blade is a background node like the others.

**H2 — `axon` can carry the always-on background tier.**
The metric is **items/hour, not tok/s** — nobody is waiting on these. Accept if
one host sustains ≥ 1 Hindsight retain per minute at the observed transcript
length, with the k3s cluster still healthy.
Reject → background work stays on `cortex-cuda` and competes with the agent.

**H3 — pooled capacity over the TB mesh beats 128 GiB on uplink's DDR4.**
Accept if RPC costs < 15% of single-node tg *and* a >64 GiB model runs at
≥ 3 tok/s at depth. **Only run this if H2 fails for capacity reasons** — it is
the most complex arm and the least likely to be needed.

**H4 — parallel small models + review beat one large model for the background
class.** The interesting one; design below. Accept if 2-model agreement ≥ 90%
against the `cortex-cuda` reference, escalation ≤ 20%, and aggregate throughput
≥ 3× the single-large-model rate on the same corpus.
Reject → small models are below the quality floor, and a wrong memory is worse
than no memory.

---

## Protocol

Hold constant across every cell: model file (by sha256), prompt corpus,
`--flash-attn`, CPU governor `performance`, and a 60 s idle before each run.
Record the fingerprint (below) or the cell is uninterpretable.

### Execution Environment

Dependencies can be satisfied natively by including `services.ai.benchmarking` in a host's NixOS aspect, or invoked dynamically via an ephemeral `nix shell`:

```bash
# Option A: Native binary execution (if host aspect includes services.ai.benchmarking)
# Option B: Ephemeral nix shell wrapper (zero pre-install required on fleet nodes)
nix shell github:NixOS/nixpkgs/nixos-unstable#sysbench \
          nixpkgs#iperf3 \
          nixpkgs#dmidecode \
          nixpkgs#llama-cpp
```

### P0 · Substrate ceilings

The **predictor**. If P1 lands far under `membw / active_bytes`, the ceiling is
the implementation, not the hardware — and that is a different bug.

```bash
sudo dmidecode -t 17 | grep -E 'Speed|Rank|Size'

# Sweep thread counts to find true RAM bandwidth ceiling before thread contention
for t in 4 8 16 32; do
  echo "=== Threads: $t ==="
  sysbench memory --memory-block-size=1M --memory-total-size=64G \
    --memory-oper=read --threads=$t run
done

# TB mesh (axon only) — latency matters more than the 20 Gbps: two hops enter
# every token's critical path under pipeline parallel
iperf3 -c <peer> -t 20 -P 4
ping -c 500 -i 0.01 -q <peer>
```

### P1 · The depth curve

`llama-bench -d` prefills to depth and then times pp/tg *there*. `d=0` is the
**live control**: if it is also slow, the finding is not about depth.

> ⚠ **Context Floor:** Explicitly pass `-c 163840` to ensure `llama-bench` allocates context space for depth testing.
> ⚠ **Blade Threading:** Pin CPU runs to P-cores with `taskset -c 0-15` or `-t 16` to prevent scheduling onto E-cores.

```bash
# Native or via `nix run github:NixOS/nixpkgs/nixos-unstable#llama-cpp -- llama-bench ...`
llama-bench -m $MODEL -c 163840 -p 4096 -n 64 -d 0,16384,65536,131072,163840 \
  -ngl $NGL -t $T -fa 1 -ctk $KV -ctv $KV -r 3 -o csv
```

Sweep: backend {cpu, vulkan(780M), hip(780M w/ `HSA_OVERRIDE_GFX_VERSION=11.0.0`), cuda(blade)} × KV {f16, q8_0, q4_0} ×
threads {8,16} (axon / blade P-cores pinned) or {16,32} (uplink).

### P2 · Cache reuse — the shape that decides "slow but correct"

An agent appends; it rarely rewrites its prefix. If the 160k prefix survives
across turns, the cold prefill amortises once per session and only delta TTFT
matters. If it doesn't, H1 is dead regardless of throughput.

```bash
# Force slot context retention with --no-context-shift
llama-server -m $MODEL -c 163840 --no-context-shift -fa 1 -ctk q8_0 -ctv q8_0 \
  --cache-reuse 256 --slot-save-path ./slots --port 8099
# 1. cold: POST a real 160k transcript, n_predict=16, cache_prompt=true
# 2. warm: same prefix + 2k delta, n_predict=128 — this is the number
```

Use a **real transcript**, not repeated filler. Filler compresses differently
in the KV cache and will flatter the result.

### P3 · Hybrid placement (blade)

The `--n-cpu-moe` dial trades VRAM for DDR5 traffic; there is one right value
per model and depth.

```bash
for ncm in 0 12 24 36 48; do
  taskset -c 0-15 llama-bench -m $MODEL -c 163840 -p 4096 -n 64 -d 0,163840 -ngl 99 \
    --n-cpu-moe $ncm -fa 1 -ctk q8_0 -ctv q8_0 -r 3 -o csv
done
```

**Thermals are a measurement, not a caveat.** Sample clocks alongside a
sustained run; report the tail, never rep 1.

```bash
nvidia-smi --query-gpu=timestamp,clocks.sm,power.draw,temperature.gpu \
  --format=csv -l 5 > thermals.csv
```

### P4 · Pooled capacity (axon, only if H3 is live)

`rpc-server -p 50052 -H 0.0.0.0` on peers, then the P1 matrix with
`--rpc a:50052,b:50052 -ngl 99` against a model that does not fit in 64 GiB.
Compare to the single-node cell. Expect capacity, not single-stream speed.

### P5 · Parallelism + review as effective compute (H4)

This arm does **not** measure tok/s. For background work the unit is *items
processed per hour at acceptable quality*, and the risk is that per-item
**prefill** dominates: a retain over a 20k-token transcript at 30 tok/s is 11
minutes, and no amount of concurrency fixes that. Measure per-item wall clock
first; if it fails, stop — the agreement study is moot.

* **Prefill Wall-Clock Gate:** If per-item TTFT for a 20k transcript exceeds **180 s** on candidate nodes, stop immediately. H4 is capacity/bandwidth bound and cannot clear the item throughput threshold.

**Corpus.** Real data we already hold: N=100 turns sampled from
`~/.hermes/state.db` (FTS5) plus N=50 entries from `~/.claude/memory/`.

**Reference.** The same extraction task run on `cortex-cuda` through the *same
harness* — same instrument, same run. A reference produced by a different code
path measures the harness, not the models.

**Arms.** Candidate small models (4B / 8B / 30B-A3B) × k concurrent slots ×
{axon, uplink}.

**Review as routing, not as ensemble.** Two different small models extract the
same item; agreement accepts, disagreement escalates to `cortex-cuda`. This
gives a real oracle instead of an ensemble hand-wave, and the escalation rate
is itself the cost model.

**Agreement Definition.** To avoid false disagreements on formatting differences, score agreement as:
1. **JSON Key Agreement:** Both model outputs extract identical structural field keys ($\ge 95\%$ overlap).
2. **Field Value Semantic Similarity:** Textual field values achieve $\ge 0.88$ cosine similarity against reference embeddings (or exact match for discrete metadata fields).

**Negative control — required.** Compute agreement between *mismatched* pairs
(reference item _i_ vs candidate item _j≠i_). Structured extraction output is
schema-shaped, so a naive agreement metric scores high on unrelated pairs. A
90% agreement figure means nothing until the shuffled floor is known.

**Record per arm:** items/hour/host · agreement vs reference · shuffled-pair
floor · escalation rate · cortex GPU-seconds displaced.

---

## Recording findings

### Raw

`docs/runbooks/results/<host>-<UTC-date>/` — llama-bench CSV **verbatim**, no
reformatting. It already carries model, backend, threads, depth, pp, tg and
stddev; do not invent a schema on top of one that exists.

### Fingerprint (one file per run dir, `env.txt`)

llama-bench does not carry these, and without them a cell cannot be reproduced
or compared across days:

```
flake rev + nixpkgs rev · llama-cpp build flags (cuda/vulkan/rpc)
model path + sha256 · quant
uname -r · cpu governor · dmidecode -t 17
nvidia-smi -q (blade) · ambient temp / docked or not (blade)
k3s node status (axon) — was the cluster loaded during the run?
```

### Findings table

One row per hypothesis cell, appended below. **A row is required before any
aspect changes** — the commit that changes `services/ai/*` cites the results
directory.

| Date | Host | Hypothesis | Cell | Result | Verdict |
|---|---|---|---|---|---|
| | | | | | |

Verdict is one of `accept` / `reject` / `inconclusive — <what was missing>`.
"Inconclusive" is a real and frequent outcome; a run that cannot distinguish
accept from reject measured nothing and should say so rather than round.

---

## Run order and stop rules

1. **P0 on every host.** Cheap, and it fixes the uplink DDR4 question that
   otherwise poisons every later estimate.
2. **blade: P1 → P3 → P2 (H1).** Blade first, not axon. If H1 accepts, we have
   a second large-context agent with no purchase, and the CPU-only
   investigation stops being about core agents.
3. **If H1 accepts → skip to P5.** Do not run P4. Pooled capacity is only
   interesting if nothing else can hold the workload.
4. **axon: P1 → P5 (H2, H4).** The background tier is needed either way — it is
   where the Hindsight consolidation work lands, and it must survive blade's
   lid closing.
5. **uplink: P1 only**, unless P5 shows the background tier is capacity-bound
   rather than bandwidth-bound.
6. **P4 last, or never.**

Stop as soon as a hypothesis accepts. The purpose is a deployment decision, not
a complete characterisation of the fleet.
