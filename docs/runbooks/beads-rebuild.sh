#!/usr/bin/env bash
# Rebuild the beads workspace from its JSONL, and take the bd->br cutover cleanup
# with it (runbook step 3, never executed: the database is still the bd-era file
# named `dolt`, metadata.json declares {"backend":"dolt"}, and ~307 MB of bd-era
# Dolt state plus a stale tracked beads.jsonl are still on disk).
# Measured 2026-08-27: .beads totals 738 MB -- .br_history 414M (br's own; CARRIED
# ACROSS explicitly at the swap, see below), embeddeddolt 203M + backup 105M (the
# bd-era debris, discarded -- that is the point), dolt 22M.
# The backup copies the whole 738 MB, not just the debris.
#
# ★ NOTHING IS BROKEN TODAY. br 0.3.2 is installed and reads this workspace fine.
#   This is PREPARATION for the br upgrade already pinned in nix-config's flake
#   (llm-agents -> beads-rust 0.5.2, committed at f199f037 but not yet switched).
#
# ★★ SEQUENCING IS LOAD-BEARING: RUN THIS WITH 0.5.2, NOT WITH 0.3.2.
#   Measured 2026-08-27 on a byte copy: a workspace freshly built BY 0.3.2 --
#   canonical beads.db, clean metadata.json, full import, no bd debris -- is STILL
#   rejected by 0.5.2 ("runtime schema remains incompatible after repair"), while
#   0.3.2 reads it at 154 ready. The incompatibility is in THE SCHEMA 0.3.2 WRITES,
#   not in the bd-era debris. Rebuilding with 0.3.2 therefore destroys and recreates
#   a database WITHOUT fixing the upgrade. 0.5.2's own init+import does work: on
#   cortex it produced 1012 issues / 151 ready from this same export.
#   => pass --br /nix/store/...-beads-rust-0.5.2/bin/br (or run after the switch).
#
# ★★ TWO BINARIES, AND THAT IS NOT AN OPTION. The live workspace was WRITTEN by the
#   old br and only the old br can read it -- that is the whole premise. So the
#   dirty-count guard and both baseline captures use --br-old (default: `br`), and
#   everything touching the NEW workspace (init, import, flush, verify, post-swap
#   read) uses --br. A single-binary version could not reach its own staging step
#   under the sequencing above: 0.5.2 would refuse the live workspace at the
#   dirty-count guard and the run would die before staging anything.
#
# ★ MEASURED IN ADVANCE, so the operator is not committing to an unobserved import
#   (0.5.2, this export, 2026-08-27, on a cortex copy): init + import + flush + a
#   whole-record diff against the source => 1015 in, 1015 out, 0 differing records;
#   close_reason 741, dependencies 425, comments 171, labels 153, notes 52 all
#   preserved; and 0.5.2 then read its own build at 154 ready. The round-trip check
#   below is still run every time -- this says the expected answer is "lossless",
#   not that the check is decorative.
#
# ★ RUN THIS FROM A TERMINAL WITH NO CLAUDE SESSION OPEN. BEADS_DIR is global, so
#   the concurrency guard refuses if ANY claude process exists anywhere -- including
#   the one an operator might use to watch the output.
#
# The rebuild is STAGED: the new workspace is built and fully verified in a temp
# directory, and the live one is only touched once that verification has passed.
# There is no window in which the live workspace is half-rebuilt.
set -euo pipefail

REPO="$HOME/Documents/repos/sini/den-ag-design"
BR="br"      # NEW binary: builds and verifies the staged workspace
BR_OLD="br"  # OLD binary: the only one that can read the existing workspace
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --br) BR="$2"; shift 2 ;;
    --br-old) BR_OLD="$2"; shift 2 ;;
    -h | --help) sed -n '2,23p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

B="$REPO/.beads"
TS="$(date +%Y%m%d-%H%M%S)"
# A SIBLING of the repo, not a child: nothing under .beads/ is gitignored for this
# pattern, and the copy is ~780 MB. Inside the checkout it would show up as untracked
# state in a repo other people commit from.
BACKUP="$REPO.beads-backup-$TS"
WORK="${TMPDIR:-/tmp}/beads-rebuild-$TS"

die() { echo "REFUSED: $*" >&2; exit 1; }
say() { echo "==> $*"; }

# A refusal after the backup exists must never leave ~780 MB unaccounted for; the
# trap fires on every non-zero exit, including the die paths above.
swapped=0
on_exit() {
  rc=$?
  if [ "$rc" -ne 0 ] && [ -e "$BACKUP" ]; then
    echo >&2
    echo "NOTE: a backup of the workspace is at $BACKUP" >&2
    if [ "$swapped" -eq 0 ]; then
      echo "      The live workspace was not swapped. If it reads correctly, delete it:" >&2
      echo "        rm -rf '$BACKUP'" >&2
    fi
  fi
  exit "$rc"
}
trap on_exit EXIT

[ -d "$B" ] || die "$B does not exist"
command -v "$BR" > /dev/null 2>&1 || [ -x "$BR" ] || die "br not executable: $BR"
command -v "$BR_OLD" > /dev/null 2>&1 || [ -x "$BR_OLD" ] || die "br-old not executable: $BR_OLD"
[ -e "$BACKUP" ] && die "backup target already exists: $BACKUP"
mkdir -p "$WORK"

say "old br (reads the live workspace): $("$BR_OLD" --version 2>&1 | head -1)"
say "new br (builds the replacement)  : $("$BR" --version 2>&1 | head -1)"
say "workspace: $B"

# --- guards. There is no override; a guard that can be walked past is not one. ---

# ★ THE HAZARD IS BEADS_DIR-SCOPED, NOT CWD-SCOPED. BEADS_DIR is pinned globally,
# so ANY session in ANY directory writes to this one workspace -- agents running in
# gen-merge, gen-scope, gen-aspects and den all reach it. A cwd==$REPO test sees
# none of them. So: refuse if any OTHER Claude process exists at all, wherever it is.
#
# Two traps that made an earlier version of this guard USELESS rather than wrong:
#  1. `pgrep -x claude` matches NOTHING -- comm is the nix wrapper `.claude-wrapped`
#     and only the cmdline reads `claude`. It silently found no holders.
#  2. Excluding "my ancestry" excludes EVERYTHING -- two sessions share the
#     terminal/systemd ancestors, so a walk to init marks every process as ours.
# Hence: cmdline matching, and exclusion bounded at our own claude pid.
#
# Subagents/children are handled BY CONSTRUCTION and do not cause a false refusal:
# is_mine walks a candidate's ANCESTORS, so anything spawned beneath our own claude
# reaches it and is excluded, at any depth. Measured 2026-08-27 -- this session's
# serena MCP server (a child, not an ancestor) classified MINE, while the other
# session's claude and ITS mcp child both classified NOT MINE. A subagent of a
# DIFFERENT session correctly counts as a holder, which is the wanted behaviour.
ppid_of() {
  # Parse after the LAST ')': a process comm may contain spaces and parentheses,
  # which shifts every positional field. A mis-parse fails toward "it is mine",
  # i.e. toward NOT refusing, so this must not be approximate.
  sed -e 's/.*) //' "/proc/$1/stat" 2> /dev/null | awk '{print $2}' | grep -E '^[0-9]+$' || echo 1
}
myclaude=0
a=$$
while [ "$a" -gt 1 ]; do
  case "$(tr '\0' ' ' < "/proc/$a/cmdline" 2> /dev/null || true)" in claude*) myclaude=$a; break ;; esac
  a=$(ppid_of "$a")
done
is_mine() {
  b=$1
  while [ "$b" -gt 1 ]; do
    [ "$b" = "$myclaude" ] && return 0
    b=$(ppid_of "$b")
  done
  return 1
}
others=""
for d in /proc/[0-9]*; do
  p=${d#/proc/}
  [ -r "$d/cmdline" ] || continue
  case "$(tr '\0' ' ' < "$d/cmdline" 2> /dev/null || true)" in claude*) ;; *) continue ;; esac
  is_mine "$p" || others="$others $p"
done
[ -z "$others" ] || die "another Claude session is running (pid$others). BEADS_DIR is global, so it can write this workspace from ANY directory. Close it first."

# Advisory only, NOT a liveness signal: measured 2026-08-27, three such locks were a
# day stale while nothing held the workspace.
stale_locks=$(find "$B" -maxdepth 1 -name '.br-*-write-*.lock' 2> /dev/null | wc -l)
[ "$stale_locks" -eq 0 ] || say "note: $stale_locks .br-*-write-*.lock present (often stale; not treated as a holder)"

if ! git -C "$REPO" diff --quiet -- .beads || ! git -C "$REPO" diff --cached --quiet -- .beads; then
  die "uncommitted .beads changes in $REPO -- commit them first, so the JSONL rebuilt from is the one in git"
fi

# ★ THE BACKUP COMES BEFORE ANY `br` READ OF THE LIVE WORKSPACE, because a read is
# not read-only: br AUTO-IMPORTS the JSONL on almost any command. Measured
# 2026-08-27 while testing this script -- against a workspace whose JSONL was behind
# its DB, the baseline capture alone silently rewrote the live database (md5
# 511324bb -> 2d1aa6a4) and dropped two issues, while an earlier version of this
# very script printed "the live workspace was never touched". Every live read below
# also passes --no-auto-import (measured to work: DB md5 unchanged with it, changed
# without it), but the ordering is what makes the restore instruction TRUE rather
# than merely likely.
say "backing up $B -> $BACKUP ($(du -sh "$B" | cut -f1))"
cp -a "$B" "$BACKUP"
say "backup complete; from here every failure is restorable with: rm -rf '$B' && mv '$BACKUP' '$B'"

dirty=$(BEADS_DIR="$B" "$BR_OLD" sync --status --json --no-auto-import 2> "$WORK/dirty.err" \
  | jq -r 'if (.dirty_count | type) == "number" then .dirty_count else "x" end' 2> /dev/null || true)
case "${dirty:-x}" in
  '' | *[!0-9]*)
    cat "$WORK/dirty.err" >&2
    die "could not read dirty_count (got '${dirty}') -- br is not answering, so the export cannot be trusted as authoritative. Restore: rm -rf '$B' && mv '$BACKUP' '$B'"
    ;;
esac
[ "$dirty" -eq 0 ] || die "$dirty unflushed DB write(s). This rebuild treats the JSONL as authoritative, so they would be LOST. Run: br sync --flush-only"

# --- baseline. stderr is CAPTURED AND SHOWN, never discarded: a 2>/dev/null here
# --- turns a broken instrument into a clean-looking absence, inside the very check
# --- that exists to catch loss.
# ★ $BR_OLD, not $BR: these read the OLD workspace. The id/status sets are then
# compared across binaries, which is sound -- an id and a status are the same datum
# either side of a schema change.
say "capturing baseline (with the old br)"
BEADS_DIR="$B" "$BR_OLD" list --all --limit 0 --json --no-auto-import 2> "$WORK/base.err" \
  | jq -r '.issues[] | [.id, (.status // "")] | @tsv' | sort > "$WORK/before.tsv"
BEADS_DIR="$B" "$BR_OLD" ready --limit 0 --json --no-auto-import 2>> "$WORK/base.err" \
  | jq -r '.[].id' | sort > "$WORK/before-ready.txt"

n_before=$(wc -l < "$WORK/before.tsv")
r_before=$(wc -l < "$WORK/before-ready.txt")
[ "$n_before" -gt 0 ] || { cat "$WORK/base.err" >&2; die "baseline read 0 issues -- refusing to rebuild against an empty baseline. Restore: rm -rf '$B' && mv '$BACKUP' '$B'"; }
# ★ r_before is guarded TOO. Left unguarded, an erroring `ready` yields empty on
# BOTH sides and the ready comparison passes VACUOUSLY.
[ "$r_before" -gt 0 ] || { cat "$WORK/base.err" >&2; die "baseline read 0 ready issues -- refusing (that comparison would be vacuous). Restore: rm -rf '$B' && mv '$BACKUP' '$B'"; }
say "baseline: $n_before issues, $r_before ready"

prefix=$(awk -F': *' '/^issue-prefix:/{print $2}' "$B/config.yaml")
[ -n "$prefix" ] || die "no issue-prefix in $B/config.yaml"

# --- stage the new workspace; the live one is untouched until it passes ----
say "staging a new workspace in $WORK/staged"
mkdir -p "$WORK/staged/.beads"
BEADS_DIR="$WORK/staged/.beads" "$BR" init > "$WORK/init.log" 2>&1 \
  || { cat "$WORK/init.log" >&2; die "br init failed"; }
# br init derives the prefix from the directory name, so the real config goes on top
# of the generated one; the generated .gitignore and metadata.json are kept.
cp -a "$B/config.yaml" "$WORK/staged/.beads/config.yaml"
cp -a "$B/issues.jsonl" "$WORK/staged/.beads/issues.jsonl"
BEADS_DIR="$WORK/staged/.beads" "$BR" sync --import-only > "$WORK/import.log" 2>&1 \
  || { cat "$WORK/import.log" >&2; die "import failed; the staged copy was not swapped in. Restore the live workspace: rm -rf '$B' && mv '$BACKUP' '$B'"; }
tail -4 "$WORK/import.log"

# --- verify the STAGED copy ------------------------------------------------
# ★ THE PRIMARY CHECK IS A WHOLE-RECORD ROUND TRIP, not a field sample. An earlier
# version compared id + status + description LENGTH, and would have reported
# VERIFIED after silently dropping every comment (171 records), label (153),
# close_reason (741) and dependency list (425) -- and two different bodies of equal
# length compare equal anyway. Re-exporting the rebuilt DB and diffing normalised
# records against the source JSONL covers every field that exists, by construction.
say "verifying the staged workspace"
BEADS_DIR="$WORK/staged/.beads" "$BR" sync --flush-only > "$WORK/flush.log" 2>&1 \
  || { cat "$WORK/flush.log" >&2; die "flush of the staged workspace failed"; }

jq -S -c '.' "$B/issues.jsonl" | sort > "$WORK/src.norm"
jq -S -c '.' "$WORK/staged/.beads/issues.jsonl" | sort > "$WORK/out.norm"
[ -s "$WORK/src.norm" ] || die "normalised source export is empty -- refusing (the round-trip check would be vacuous)"

fail=0
if ! diff -q "$WORK/src.norm" "$WORK/out.norm" > /dev/null; then
  # ★ `jq -S` sorts KEYS but not ARRAY ELEMENTS, so a merely reordered dependencies
  # or comments list reads as lossy. Failing closed on that is right -- but the
  # operator must be able to tell "reordered" from "dropped" in one look, and a
  # dump of the first 10 differing records cut to 200 chars does not. So: re-compare
  # with arrays sorted too, and report WHICH FIELDS differ rather than which records.
  jq -S -c 'walk(if type == "array" then sort else . end)' "$B/issues.jsonl" | sort > "$WORK/src.deep"
  jq -S -c 'walk(if type == "array" then sort else . end)' "$WORK/staged/.beads/issues.jsonl" | sort > "$WORK/out.deep"
  if diff -q "$WORK/src.deep" "$WORK/out.deep" > /dev/null; then
    kind="ORDER-ONLY -- array element order differs, no content lost"
  else
    kind="CONTENT -- records or field values genuinely differ"
  fi
  echo "MISMATCH: round trip not byte-equal. Class: $kind" >&2
  echo "  differing records: $(diff "$WORK/src.norm" "$WORK/out.norm" | grep -c '^[<>]')" >&2
  echo "  fields that differ:" >&2
  jq -r 'keys[]' "$B/issues.jsonl" | sort -u > "$WORK/fields.txt"
  while read -r f; do
    fa=$(jq -S -c --arg f "$f" '{id: .id, v: .[$f]}' "$B/issues.jsonl" | sort | md5sum | cut -d' ' -f1)
    fb=$(jq -S -c --arg f "$f" '{id: .id, v: .[$f]}' "$WORK/staged/.beads/issues.jsonl" | sort | md5sum | cut -d' ' -f1)
    [ "$fa" = "$fb" ] || echo "    - $f" >&2
  done < "$WORK/fields.txt"
  fail=1
fi

BEADS_DIR="$WORK/staged/.beads" "$BR" list --all --limit 0 --json 2> "$WORK/after.err" \
  | jq -r '.issues[] | [.id, (.status // "")] | @tsv' | sort > "$WORK/after.tsv"
BEADS_DIR="$WORK/staged/.beads" "$BR" ready --limit 0 --json 2>> "$WORK/after.err" \
  | jq -r '.[].id' | sort > "$WORK/after-ready.txt"
[ -s "$WORK/after.tsv" ] || { cat "$WORK/after.err" >&2; die "the staged workspace reads 0 issues"; }

if ! diff -q "$WORK/before.tsv" "$WORK/after.tsv" > /dev/null; then
  echo "MISMATCH: id/status set changed:" >&2
  diff "$WORK/before.tsv" "$WORK/after.tsv" | head -10 >&2
  fail=1
fi
if ! diff -q "$WORK/before-ready.txt" "$WORK/after-ready.txt" > /dev/null; then
  echo "MISMATCH: ready set changed:" >&2
  diff "$WORK/before-ready.txt" "$WORK/after-ready.txt" | head -10 >&2
  fail=1
fi
p_after=$(awk -F': *' '/^issue-prefix:/{print $2}' "$WORK/staged/.beads/config.yaml")
[ "$p_after" = "$prefix" ] || { echo "MISMATCH: prefix '$p_after' != '$prefix'" >&2; fail=1; }

[ "$fail" -eq 0 ] || die "VERIFICATION FAILED on the STAGED copy; it was NOT swapped in. Staged copy left at $WORK/staged for inspection. The live workspace may still have been auto-imported by the baseline read, so restore it regardless: rm -rf '$B' && mv '$BACKUP' '$B'"

say "staged copy VERIFIED: $(wc -l < "$WORK/after.tsv") issues, $(wc -l < "$WORK/after-ready.txt") ready, round trip lossless"

# --- swap in the verified copy ---------------------------------------------
# ★ CARRY BR'S OWN ROLLBACK HISTORY ACROSS. A fresh `br init` does not create
# .br_history, so a straight swap would silently discard it -- measured on the live
# workspace: 414 MB, 200 snapshots. Its snapshots are of issues.jsonl, which this
# rebuild does not change, so they stay valid and are worth keeping. (An earlier
# revision of this header claimed .br_history was "kept by the rebuild" while the
# swap in fact dropped it; this is what makes that claim true.)
for keep in .br_history .br_recovery; do
  if [ -e "$B/$keep" ]; then
    say "carrying $keep across ($(du -sh "$B/$keep" | cut -f1))"
    cp -a "$B/$keep" "$WORK/staged/.beads/$keep"
  fi
done

# Name every TRACKED file the swap removes, so none of it is a surprise in a later
# `git status`. All three are bd-era: the hooks gate on a `bd` binary that is gone,
# beads.jsonl is its frozen export, README.md documents `bd` commands and links to
# github.com/steveyegge/beads.
say "the swap removes these TRACKED files (all bd-era; see the closing note):"
for t in $(git -C "$REPO" ls-files .beads); do
  base=$(echo "${t#.beads/}" | cut -d/ -f1)
  [ -e "$WORK/staged/.beads/$base" ] || echo "      $t"
done

say "swapping the verified workspace in"
swapped=1
rm -rf "$B"
cp -a "$WORK/staged/.beads" "$B"

BEADS_DIR="$B" "$BR" ready --limit 0 --json > "$WORK/final.out" 2> "$WORK/final.err" \
  || { cat "$WORK/final.err" >&2; die "the swapped-in workspace does not read. Restore: rm -rf '$B' && mv '$BACKUP' '$B'"; }
final=$(jq -r 'if type == "array" then length else "BAD" end' "$WORK/final.out")
[ "$final" = "$r_before" ] || die "post-swap ready count $final != baseline $r_before. Restore: rm -rf '$B' && mv '$BACKUP' '$B'"

say "DONE: $B rebuilt, $final ready, database $(BEADS_DIR="$B" "$BR" where 2> /dev/null | awk '/database:/{print $2}')"
echo
echo "Still to do by hand -- TRACKED files, so they want a reviewed commit:"
echo "  git -C $REPO rm -r --cached .beads/hooks     # bd's hooks, gated on a 'bd' that is gone"
echo "  git -C $REPO rm --cached .beads/beads.jsonl  # bd-era export, frozen at 982 lines"
echo "  git -C $REPO rm --cached .beads/README.md     # documents 'bd', links to steveyegge/beads"
echo "  git -C $REPO add .beads/.gitignore .beads/metadata.json"
echo "Delete the backup only after a full session has run on the rebuilt workspace:"
echo "  rm -rf $BACKUP"
