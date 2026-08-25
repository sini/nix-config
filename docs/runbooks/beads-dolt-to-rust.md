# Runbook: migrate the beads tracker from `bd` (Dolt) to `br` (SQLite + JSONL)

The tracker for every `gen-*` repo lives in one workspace,
`~/Documents/repos/sini/den-ag-design/.beads`, pinned fleet-wide by `BEADS_DIR`.
This runbook cuts that workspace over from `bd` (github:gastownhall/beads,
Dolt-backed) to `br` (github:Dicklesworthstone/beads_rust, SQLite + JSONL).

**Do not start while a den-ag-design round is in flight.** The tracker is the
only record of the arc state; the cutover rewrites its storage.

## Already in place

`modules/den/aspects/applications/dev/ai/beads.nix` is the single aspect owning
the tracker. It already installs both binaries and registers upstream's
`bd-to-br-migration` skill, so nothing needs to be built at cutover time:

| Piece                                           | State                                      |
| ----------------------------------------------- | ------------------------------------------ |
| `bd` (`inputs'.beads.packages.default`)         | installed, **active**                      |
| `br` (`inputs'.llm-agents.packages.beads-rust`) | installed, staged                          |
| `beads-viewer`                                  | installed                                  |
| `BEADS_DIR`                                     | pinned; **both** implementations honour it |
| `Bash(bd *)`, `Bash(br *)`                      | both allowed                               |
| skill `bd-to-br-migration`                      | registered (doc transforms only)           |
| plugin `beads@beads-marketplace` (bd)           | enabled                                    |
| plugin `beads@beads-rust` (br)                  | **not registered** — see step 4            |

## Measured before writing this (br 0.3.2 vs bd 1.2.2, the live 982-issue export)

Every row below was reproduced against a scratch import of the live
`issues.jsonl`. None is a version regression — the `Comment.id` type and the
missing `-C` flag are identical in the 0.5.1 tree at
`~/Documents/repos/beads_rust`.

| Surface                       | `bd` 1.2.2                                  | `br` 0.3.2                       | Consequence                                                                                                                                                  |
| ----------------------------- | ------------------------------------------- | -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| JSONL import                  | —                                           | rejects bd's export              | `comments[].id` is a UUID string, br wants `i64`. Step 2 fixes it; all 982 then import clean                                                                 |
| `show --json` envelope        | array                                       | array                            | `jq '.[0] \| …'` is unchanged                                                                                                                                |
| `show --json` comments        | **absent**                                  | **present, full bodies**         | inverts. `den-hoag-4kh.6` goes 25.8 KB → 206 KB                                                                                                              |
| `show --brief-deps`           | flag                                        | **no such flag**                 | none needed — br's deps are already `{id,title,status,priority,dependency_type}`                                                                             |
| `list --json` envelope        | bare array                                  | **object** `{"issues":[…]}`      | `jq '.[]'` yields nothing under br. `br show`/`br ready` stay arrays, so br is inconsistent with _itself_ — a sweeper that works on `ready` breaks on `list` |
| `list --all --limit 0 --json` | —                                           | same rows, same fields           | `id`/`title`/`description`/`close_reason`/`status`/`labels` all present — **the C10 sweep survives intact** once the accessor is fixed                       |
| `list --json` `comment_count` | present on every row                        | **absent**                       | `.comment_count // 0` silently reads a vacuous zero                                                                                                          |
| `-C <path>`                   | yes                                         | **no such flag**                 | only `BEADS_DIR=…` or `--db`                                                                                                                                 |
| `ready --limit 0 --json`      | array, honours epic parking                 | array, **does not**              | +26 rows: open children whose only dep is `parent-child` to an open parent, all under the frozen `4kh.*`/`9xo.*` epics                                       |
| `stats` "Ready to Work"       | `open − blocked`, ≠ `ready`                 | **equals** the `ready` count     | ready and blocked both rise; total, open, in-progress and closed are unaffected. Step 6 check 4 quantifies it against your own baseline                      |
| `search`                      | ruled "measured broken"                     | returns the same first hit as bd | the ruling was made against bd — re-measure it, do not carry it forward                                                                                      |
| `sync`                        | auto-commits to git                         | `--flush-only`, never runs git   | every sync site needs `git add .beads/ && git commit` after it                                                                                               |
| git hooks                     | `.beads/hooks/*` tracked, **not installed** | none                             | `core.hooksPath` is `.git/hooks` and the only live hook there is the nix `pre-commit`. Delete the tracked dir; there is nothing to uninstall                 |

Two of these are not find-replace and must be decided before step 4:

- **The parked-children delta.** `den-hoag-zweu` is standing law that `bd ready`
  honours epic parking and `bd stats` does not. Under br the two agree and
  _neither_ honours it, so the frontier grows by the frozen-track children.
  Either add `blocked-by` edges to the frozen epics or accept a wider `ready`.
- **`comment_count` vanishing from `list`.** `den-hoag-555g`'s interim
  workaround reads it off the list payload. Under br that read returns nothing
  and `// 0` makes it look like a real zero — the exact vacuous-zero shape 555g
  was filed about. The replacement is `br show --json` `.comments` directly.

## What the fork costs (measured, not inferred)

br is a port of the _classic_ SQLite + JSONL beads, deliberately frozen before
the Dolt era, so the gap is architectural. bd exposes 117 commands, br 0.3.2
exposes 45 — but 82-absent is the wrong number to reason from. Counting actual
`bd <verb>` call sites across the live instruction surface, all 982 bead bodies
and comments, and the 14 memory files: **7 absent commands are used, at 50 call
sites**, and six of them are moot or trivially replaced.

The call-site counts below are a snapshot; the _replacement mapping_ is what
carries. Re-derive with:

```bash
cd ~/Documents/repos/sini/den-ag-design
{ git ls-files -z STATUS CLAUDE.md .agents ci | xargs -0 cat
  jq -r '.description, (.comments[]?.text)' .beads/issues.jsonl
  cat ~/.claude/memory/*.md
} | grep -oE '(^|[^A-Za-z0-9_/-])bd [a-z][a-z0-9-]+' \
  | awk '{print $NF}' | sort | uniq -c | sort -rn
```

| Absent in br  | Call sites | Replacement                                                 |
| ------------- | ---------- | ----------------------------------------------------------- |
| `bd export`   | 32         | `br sync --flush-only` — exact                              |
| `bd comment`  | 7          | `br comments add` — exact                                   |
| `bd prime`    | 6          | **none — see below**                                        |
| `bd hooks`    | 2          | moot: br never runs git, and the hooks were never installed |
| `bd edit`     | 1          | moot: already forbidden for agents ($EDITOR blocks)         |
| `bd dolt`     | 1          | moot by definition                                          |
| `bd memories` | 1          | moot for us: knowledge lives in `~/.claude/memory`          |

**The one real loss is `bd prime` and its hook wiring.** bd's plugin registers
SessionStart/PreCompact hooks that auto-run it; br's plugin ships `skills/` and
**no hooks directory at all**, so nothing fires on compaction. What `bd prime`
emits is 5.9 KB of generic protocol boilerplate, not project state — our actual
recovery path is RESUME-PROMPT-ARCH.md + HANDOFF.md, which is richer and
project-specific. So the replacement is ours to wire: a SessionStart hook in
`beads.nix` pointing at the boot document. Decide that at step 4; it is the only
gap without an upstream answer.

Not used by us today, but worth knowing they are gone for good — measured absent
from the 0.5.1 tree as well, so they are not coming back:

- **Dolt everything** — `branch`, `diff`, `conflicts`, `federation`, `sql`,
  `worktree`. The deliberate trade: git over the JSONL replaces it.
- **`compact`/`gc`/`prune`** — bd can compact old closed issues. With 649 closed
  in a 6.4 MB JSONL this is comfortable, but it is the scaling ceiling.
- **`remember`/`recall`/`memories`/`kv`** — bd's knowledge store. We already
  override its advice against `MEMORY.md`, so no change.
- **`supersede`, `promote`, `preflight`, `human`, `restore`** —
  close-with-reason plus a `relates-to` edge covers `supersede`; the rest are
  unused.
- **Lease coordination** — `heartbeat`, `reclaim`, `unclaim`, `merge-slot`, and
  the atomic `--if-assignee`/`--if-status` guards (absent in 0.3.2 _and_ 0.5.1).
  `br update --claim` exists, but the compare-and-set guard does not. br answers
  the same problem differently, with `capacity`, `coordination`, `scheduler` and
  `gate` — cooperative admission control rather than leases. For swarm work that
  is a design change to evaluate, not a like-for-like substitution.
- Integrations (`github`, `jira`, `linear`, `notion`, …) and workflow templates
  (`formula`, `mol`, `cook`, `ship`, `swarm`) — unused here.

br is not strictly behind: `capabilities`, `robot-docs`, `schema`, `scheduler`,
`capacity`, `coordination`, `vcs-status` and `changelog` have no bd equivalent.

## Steps

### 1. Freeze and back up

```bash
cd ~/Documents/repos/sini/den-ag-design
# Capture the step-6 baselines now, before anything is touched — see step 6.
bd sync                                   # flush Dolt -> .beads/issues.jsonl

# ★ VERIFY THE FLUSH. The export lags the database whenever a session is in
# flight, and br imports the EXPORT — so an unflushed edit is simply gone, with
# no error anywhere. Measured while writing this runbook: the live export was
# ~2h behind the DB on 4 beads totalling 14.5 KB of description, because a
# session was mid-round. This must print nothing.
diff <(bd list --all --limit 0 --json | jq -r '.[] | "\(.id)\t\(.description|length)"' | sort) \
     <(jq -r '"\(.id)\t\(.description|length)"' .beads/issues.jsonl | sort) \
  && echo "OK: export matches the database"
git status --porcelain .beads/            # expect the export to be the only churn
cp -a .beads .beads.dolt-backup           # full rollback point, NOT committed
```

### 2. Transform the export (the `comments[].id` fix)

```bash
cd ~/Documents/repos/sini/den-ag-design
python3 - <<'PY'
import json, pathlib
p = pathlib.Path(".beads/issues.jsonl")
n, out = 0, []
for line in p.read_text().splitlines():
    if not line.strip():
        continue
    d = json.loads(line)
    for c in d.get("comments") or []:
        if isinstance(c.get("id"), str):
            n += 1
            c["id"] = n
    out.append(json.dumps(d, separators=(",", ":")))
p.write_text("\n".join(out) + "\n")
print(f"records={len(out)} comment_ids_rewritten={n}")
PY
```

Comment IDs are renumbered, not preserved — bd's UUIDs have no consumer outside
bd's own storage. Everything else passes through byte-identical.

### 3. Rebuild the workspace under `br`

`br init` writes `.beads/beads.db` beside the JSONL; the Dolt state in
`embeddeddolt/` becomes dead weight.

```bash
cd ~/Documents/repos/sini/den-ag-design
mv .beads/issues.jsonl /tmp/issues.jsonl.migrated
rm -rf .beads/embeddeddolt .beads/beads.jsonl .beads/config.yaml .beads/metadata.json \
       .beads/.local_version .beads/last-touched .beads/embeddeddolt.gate.lock \
       .beads/backup .beads/hooks
br init                                   # confirm the prefix it reports is den-hoag
mv /tmp/issues.jsonl.migrated .beads/issues.jsonl
br sync --import-only
br stats                                  # against /tmp/bd-stats-before.txt, and the §2 deltas
br where                                  # must print the BEADS_DIR workspace
```

If `br init` picks the wrong prefix, fix it in `.beads/config.yaml` before the
import — the prefix stays `den-hoag`.

`.beads/hooks/` goes with the Dolt state: those are bd's git hooks, tracked but
never installed (`core.hooksPath` is `.git/hooks`, whose only live hook is the
nix-generated `pre-commit`), and br runs no git at all. `br init` writes a fresh
`.beads/.gitignore` covering the SQLite artefacts — `beads.db`, `-wal`, `-shm`,
`-wal-cert*`, `-fsqlite-ns-*`, `.write.lock`, `.br-db-write-*.lock`. Keep br's
version and commit it; the root `.gitignore` needs the same review.

### 4. Cut the config over

Three hunks in `modules/den/aspects/applications/dev/ai/beads.nix`:

1. Drop `inputs'.beads.packages.default` from `home.packages` and delete the
   `flake-file.inputs.beads` block, then `nix run .#write-flake`.
2. Replace the marketplace + plugin pair. Upstream also names its plugin
   `beads`, which is why only one can be live at a time:

   ```nix
   marketplaces.beads-rust = inputs'.llm-agents.packages.beads-rust.src;
   settings.enabledPlugins."beads@beads-rust" = true;
   ```

   (drop `marketplaces.beads-marketplace` and
   `settings.enabledPlugins."beads@beads-marketplace"`.)

3. Drop `"Bash(bd *)"` from `settings.permissions.allow`.

Decide the `br` version at this point. The pinned `llm-agents` input carries
**0.3.2**; upstream HEAD carries 0.4.1 and the local clone is 0.5.1. Either bump
the single input (`nix flake update llm-agents` — moves rtk, hunk, codegraph,
herdr and pi too, so build every host after) or add
`github:Dicklesworthstone/beads_rust` as its own input, which drags in a fenix
nightly toolchain and crane and ships no `flake.lock`.

```bash
nix fmt -- modules/den/aspects/applications/dev/ai/beads.nix
nix-flake-build cortex
nix flake check
colmena apply --on @prod
```

### 5. Migrate the instruction surface

> **Every count in this section is a snapshot, taken 2026-08-25 against a live
> repo.** `STATUS/HANDOFF.md` is wholesale-replaced at every session close, bead
> bodies are edited continuously, and the tracker figures move with them.
> Re-derive before trusting any number here — the shape of the finding is what
> carries, not the arithmetic:
>
> ```bash
> cd ~/Documents/repos/sini/den-ag-design
> CMD='(^|[^a-zA-Z0-9_-])bd (ready|list|show|create|update|close|dep|stats|sync|prime|export|import|search|blocked|comments|doctor|defer|reopen|delete|epic|label|init|config|audit|-C)\b'
> # live instruction surface, by file
> git ls-files -z STATUS CLAUDE.md .agents ci | xargs -0 grep -cE "$CMD" | grep -v ':0$'
> # bead bodies carrying commands (descriptions are the load-bearing channel)
> jq -r 'select((.description // "") | test("(^|[^A-Za-z0-9_-])bd (ready|list|show|update|close|search|sync|export)")) | .id' .beads/issues.jsonl | sort
> # live memory (.stversions is Syncthing history — exclude it)
> grep -rlE "$CMD" --exclude-dir=.stversions ~/.claude/memory
> ```

`br` never touches git. Every `bd sync` instruction in the tree is wrong after
cutover, and a stale instruction in a _gate_ is worse than a broken one. Work
outward from the entrypoint; the registered `bd-to-br-migration` skill drives
the mechanical transforms and `scripts/find-bd-refs.sh` is the oracle.

**A. The entrypoint pair** — `STATUS/RESUME-PROMPT-ARCH.md` (31 matching lines)
then `STATUS/HANDOFF.md` (7). Beyond the rename, four claims in RESUME-PROMPT
become false and are load-bearing:

- "it drops dependency bodies natively (bd `--brief-deps`) and comments by
  construction (the JSON payload omits them)" — br's JSON **carries** comments.
  The rendered output stays comment-free because the jq selects `.description`,
  so rewrite the _reason_, not the pipeline: comments are dropped by the render,
  not by the payload.
- The measured sizes cited inline (315 KB on 4kh.6, ~293 KB of it sediment; five
  boot beads 105 KB raw wrapping 34 KB) were measured on bd. Re-measure or drop
  them — a false citation in the boot document is worse than no citation.
- "Prefer `bd -C <path>` anyway" — br has no `-C`. The substitute is
  `BEADS_DIR=<path> br …` (already pinned fleet-wide) or `--db`.
- "`bd search` is measured broken; do not use it" — `br search` returns the same
  first hit as bd. Re-measure before carrying a prohibition that would suppress
  a working tool.

The same file carries two **bare, in-context JSON calls** that its own
compression-trap paragraph does not cover — that warning is scoped to
`bd show`/`bd-cat.sh` only:

```
bd ready --limit 0 --json | jq 'map({id,title,priority,status})'
bd list  --all --limit 0 --json     # THE C10 PRIOR-ART SWEEP — RUNS FIRST
```

Neither should emit JSON at all. The consumer here is the model, and a model
reads structure out of plain lines perfectly well — JSON's braces are dead
tokens and are the shape a token-optimizer has the most leverage over, which is
why C10 (which runs before any check on the merits) can come back compressed and
report clean. Do not route the payload to disk to survive that; drop the format.
JSON belongs _inside_ a script, feeding `jq` — which is exactly what `bd-cat.sh`
already does, and the pattern both of these should adopt:

```bash
br ready --limit 0 --json \
  | jq -r '.[] | "\(.id)  p\(.priority)  \(.status)  \(.title)"'
```

C10 needs the same treatment plus a filter. It is a sweep of the artefact's
vocabulary over the corpus, and today it hands the model all 982 bodies to grep
mentally. The terms belong in the script: pass them in, match on
title+description+close_reason inside `jq`, render the hits as markdown. That
turns a 6.38 MB payload into the handful of rows the reviewer actually cites,
and the sweep stops depending on whether the corpus survived compression.

Two shortcuts look like the fix and are not, both measured on the 982-row
export:

- `--format toon` is **6.41 MB against JSON's 6.38 MB** — larger, despite the
  token-optimized framing.
- `--format text` is 201 KB, 32× smaller, because it carries **no descriptions**
  (0 hits for a known description string; ~205 bytes/row, title only). C10 reads
  title+description+close*reason, so text is a \_different* instrument, not a
  cheaper one — substituting it makes the sweep vacuous. The render-and-filter
  script above is what gets both the size and the fields.

**B. The two tools** — both are called by the boot path, so a silent break here
is a gate that passes without measuring.

- `STATUS/bd-cat.sh` — drop `--brief-deps` (no br equivalent, and unneeded);
  `bd show` → `br show`; the `jq -r -e '.[0] | …'` render is unchanged. Rewrite
  the header comment: its whole rationale cites bd's comment-omitting JSON,
  which br inverts. Rename the file to `br-cat.sh` and fix the two call sites in
  RESUME-PROMPT-ARCH.md. Also drop its retirement clause — it currently promises
  to retire "when bd grows a comments-free body/text output", which framed it as
  a workaround. It is not one: structured in, rendered out is the shape every
  model-facing tracker read should have, and no upstream flag retires that.
- `STATUS/handoff-gate.sh` — `bd list --all --limit 0 --json` → `br list …`
  works flag-for-flag, and `command -v bd` → `command -v br`. **But its jq must
  change from `.[]` to `.issues[]`**: br wraps `list` in an object. The gate
  reads that query under `2>/dev/null`, so the wrong accessor yields an empty id
  set, `id_src` stays unset, and it falls to the loud NO-BEAD-ID-SOURCE path —
  detectable, but the bare-id half of the check is silently gone until someone
  reads the warning. The prose is what needs care: the gate documents its id
  source as "SOURCE OF TRUTH IS DOLT, REACHED THROUGH bd" and treats
  `issues.jsonl` as a passive export that makes the gate fail open. Under br the
  database is SQLite and the export is auto-flushed, so the degraded-fallback
  warning text must be restated. Verify with `STATUS/handoff-gate.sh --worktree`
  against a known-drop handoff before trusting a pass.

**C. The mandatory boot beads.** Three of the five carry commands in their
bodies — `den-hoag-4kh.6` (8 lines + 1 comment), `den-hoag-pdlh` (2),
`den-hoag-qnlx` (1); `bfj6` and `rlsm` carry none. 4kh.6 is the rubric whose C10
sweep RUNS FIRST, and it additionally carries bd-version-specific measurements
("at bd 1.2.1 (dev), `bd list --json` does NOT emit close_reason") that are
meaningless under br. The sweep itself survives — re-measure the claims around
it.

Three further open beads are _about_ bd and are resolved or inverted rather than
renamed. Triage them at cutover; do not find-replace them:

| Bead                                                                                     | Under `br`                                                                                                                       |
| ---------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `den-hoag-zweu` — `bd stats` Ready is status arithmetic, `bd ready` honours epic parking | **inverts** — the two agree and neither honours parking                                                                          |
| `den-hoag-555g` — `--include-comments --json` emits no comments key                      | **resolved** — br's `show --json` always carries them; delete the interim `comment_count` advice, which now reads a vacuous zero |
| `den-hoag-4xoz` — bd resolves its workspace from CWD, wants a cwd-independent bd         | **worse** — br has no `-C` at all; `BEADS_DIR` (already pinned by the nix aspect) is the whole mitigation                        |

Fleet-wide, 165 bead descriptions contain bd commands. Only the instruction
carriers above need rewriting — the rest are historical record.

**D. Memory** — 14 live files under `~/.claude/memory` carry bd mechanics
(`.stversions/` is Syncthing history, leave it). By weight:
`reference_shell_grep_wrapper.md` (18 matches — including the standing "bd needs
no cwd" claim, which is what `-C`'s absence makes load-bearing),
`reference_measurement_traps.md` (10), then `project_kernel_purity_arc.md`,
`project_gen_tracker_scope.md`, `feedback_process_strip_back.md` (3 each), and
`MEMORY.md`, `reference_headroom_compression.md`,
`project_gen_consolidation.md`, `project_den_hoag_features.md`,
`feedback_never_end_on_a_question.md`,
`feedback_link_rulings_to_standing_law.md`,
`feedback_agent_dispatch_discipline.md`,
`feedback_orchestrator_theory_first.md`, `feedback_no_self_complete_tasks.md`
(1-2 each). Per the memory rules, fix the `description:` and the `MEMORY.md`
index line **before** the body — a body-only edit leaves the rule unreachable.

**E. Do not migrate.** `reports/` (205 files), `used/`, `archive/` and
`den-hoag-fail-forensics/` (9) are frozen record. Rewriting them would carry
today's claims onto artefacts where they were never true.

Verify each edited file two ways: no surviving `bd` invocations, and a git step
after every sync.

```bash
grep -nE '(^|[^a-zA-Z0-9_-])bd [a-z]' <file>   # must be empty
grep -c 'br sync --flush-only' <file>          # must be > 0 where a sync is instructed
```

### 6. Verify

Nothing here asserts a number. Every check compares the migrated workspace
against the baseline captured in step 1, so it stays correct however far the
tracker has moved since this runbook was written. All four print nothing on
success — and each one fails loudly if the migration lost something.

```bash
cd ~/Documents/repos/sini/den-ag-design
a=/tmp/beads-migration

# 1. NO ISSUE VANISHED — set comparison, not a count: equal counts hide an
#    equal-sized swap.
br list --all --limit 0 --json | jq -r '.issues[].id' | sort > $a/br-ids.txt
diff $a/bd-ids.txt $a/br-ids.txt && echo "OK ids"

# 2. NO STATUS DRIFTED.
br list --all --limit 0 --json | jq -r '.issues[] | "\(.id)\t\(.status)"' | sort > $a/br-status.txt
diff $a/bd-status.txt $a/br-status.txt && echo "OK statuses"

# 3. NO BODY WAS TRUNCATED — description length per id.
br list --all --limit 0 --json \
  | jq -r '.issues[] | "\(.id)\t\(.description | length)"' | sort > $a/br-bodies.txt
diff $a/bd-bodies.txt $a/br-bodies.txt && echo "OK bodies"

# 4. THE EXPECTED READY DELTA, as a PREDICATE not a number. Every id br calls
#    ready that bd did not must be an open child whose only dependency edges are
#    parent-child. Anything else is a regression, and this names it.
br ready --limit 0 --json | jq -r '.[].id' | sort > $a/br-ready.txt
comm -13 $a/bd-ready.txt $a/br-ready.txt > $a/ready-delta.txt
jq -r --rawfile delta $a/ready-delta.txt '
  ($delta | split("\n") | map(select(length > 0))) as $d
  | select(.id as $i | $d | index($i))
  | select(.status != "open" or any(.dependencies[]?; .type != "parent-child"))
  | "UNEXPECTED IN READY DELTA: \(.id) [\(.status)]"' .beads/issues.jsonl

br doctor                        # no orphans, no broken dependencies
br where                         # must print the BEADS_DIR workspace
git status --porcelain .beads/
```

Step 1 captures the four baselines these compare against, from bd, before
anything is touched:

```bash
a=/tmp/beads-migration; mkdir -p $a
bd list --all --limit 0 --json | jq -r '.[].id' | sort > $a/bd-ids.txt
bd list --all --limit 0 --json | jq -r '.[] | "\(.id)\t\(.status)"' | sort > $a/bd-status.txt
bd list --all --limit 0 --json \
  | jq -r '.[] | "\(.id)\t\(.description | length)"' | sort > $a/bd-bodies.txt
bd ready --limit 0 --json | jq -r '.[].id' | sort > $a/bd-ready.txt
```

Then run one real session end to end: `br ready`, claim an issue, append to a
body, `br sync --flush-only`, `git add .beads/ && git commit`.

## Rollback

Nothing is destroyed until `.beads.dolt-backup` is removed.

```bash
cd ~/Documents/repos/sini/den-ag-design
rm -rf .beads && mv .beads.dolt-backup .beads
git -C ~/Documents/repos/sini/nix-config revert <cutover-commit>
nix-flake-build cortex --apply
```

Delete `.beads.dolt-backup` only after a full session has run on `br`.
