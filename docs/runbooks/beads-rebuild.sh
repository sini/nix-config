#!/usr/bin/env bash
# Rebuild the beads workspace from its JSONL, and take the bd->br cutover cleanup
# with it (runbook step 3, never executed: the database is still the bd-era file
# named `dolt`, metadata.json declares {"backend":"dolt"}, and ~318 MB of Dolt
# state plus a stale tracked beads.jsonl are still on disk).
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
# The rebuild is STAGED: the new workspace is built and fully verified in a temp
# directory, and the live one is only touched once that verification has passed.
# There is no window in which the live workspace is half-rebuilt.
set -euo pipefail

REPO="$HOME/Documents/repos/sini/den-ag-design"
BR="br"
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --br) BR="$2"; shift 2 ;;
    -h | --help) sed -n '2,23p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

B="$REPO/.beads"
TS="$(date +%Y%m%d-%H%M%S)"
# Outside the repo on purpose: .beads.pre-rebuild-* is not gitignored, and this is
# ~780 MB. It must not appear as untracked state at the root of a live checkout.
BACKUP="$REPO.beads-backup-$TS"
WORK="${TMPDIR:-/tmp}/beads-rebuild-$TS"

die() { echo "REFUSED: $*" >&2; exit 1; }
say() { echo "==> $*"; }

[ -d "$B" ] || die "$B does not exist"
command -v "$BR" > /dev/null 2>&1 || [ -x "$BR" ] || die "br not executable: $BR"
[ -e "$BACKUP" ] && die "backup target already exists: $BACKUP"
mkdir -p "$WORK"

say "br in use: $("$BR" --version 2>&1 | head -1)   workspace: $B"

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

dirty=$(BEADS_DIR="$B" "$BR" sync --status --json 2> "$WORK/dirty.err" \
  | jq -r 'if (.dirty_count | type) == "number" then .dirty_count else "x" end' 2> /dev/null || true)
case "${dirty:-x}" in
  '' | *[!0-9]*)
    cat "$WORK/dirty.err" >&2
    die "could not read dirty_count (got '${dirty}') -- br is not answering, so the export cannot be trusted as authoritative"
    ;;
esac
[ "$dirty" -eq 0 ] || die "$dirty unflushed DB write(s). This rebuild treats the JSONL as authoritative, so they would be LOST. Run: br sync --flush-only"

if ! git -C "$REPO" diff --quiet -- .beads || ! git -C "$REPO" diff --cached --quiet -- .beads; then
  die "uncommitted .beads changes in $REPO -- commit them first, so the JSONL rebuilt from is the one in git"
fi

# --- baseline. stderr is CAPTURED AND SHOWN, never discarded: a 2>/dev/null here
# --- turns a broken instrument into a clean-looking absence, inside the very check
# --- that exists to catch loss.
say "capturing baseline"
BEADS_DIR="$B" "$BR" list --all --limit 0 --json 2> "$WORK/base.err" \
  | jq -r '.issues[] | [.id, (.status // "")] | @tsv' | sort > "$WORK/before.tsv"
BEADS_DIR="$B" "$BR" ready --limit 0 --json 2>> "$WORK/base.err" \
  | jq -r '.[].id' | sort > "$WORK/before-ready.txt"

n_before=$(wc -l < "$WORK/before.tsv")
r_before=$(wc -l < "$WORK/before-ready.txt")
[ "$n_before" -gt 0 ] || { cat "$WORK/base.err" >&2; die "baseline read 0 issues -- refusing to rebuild against an empty baseline"; }
# ★ r_before is guarded TOO. Left unguarded, an erroring `ready` yields empty on
# BOTH sides and the ready comparison passes VACUOUSLY.
[ "$r_before" -gt 0 ] || { cat "$WORK/base.err" >&2; die "baseline read 0 ready issues -- refusing (that comparison would be vacuous)"; }
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
  || { cat "$WORK/import.log" >&2; die "import failed (live workspace untouched)"; }
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
  echo "MISMATCH: the round trip is LOSSY ($(diff "$WORK/src.norm" "$WORK/out.norm" | grep -c '^[<>]') differing records). First 10:" >&2
  diff "$WORK/src.norm" "$WORK/out.norm" | head -10 | cut -c1-200 >&2
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

[ "$fail" -eq 0 ] || die "VERIFICATION FAILED on the STAGED copy. The live workspace was never touched, so there is nothing to restore. Staged copy left at $WORK/staged for inspection."

say "staged copy VERIFIED: $(wc -l < "$WORK/after.tsv") issues, $(wc -l < "$WORK/after-ready.txt") ready, round trip lossless"

# --- only now touch the live workspace -------------------------------------
say "backing up $B -> $BACKUP ($(du -sh "$B" | cut -f1))"
cp -a "$B" "$BACKUP"

say "swapping the verified workspace in"
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
echo "  git -C $REPO add .beads/.gitignore .beads/metadata.json"
echo "Delete the backup only after a full session has run on the rebuilt workspace:"
echo "  rm -rf $BACKUP"
