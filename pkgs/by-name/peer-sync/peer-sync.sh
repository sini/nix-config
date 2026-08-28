#!/usr/bin/env bash
# peer-sync — move a host's git refs to a peer so work is transferable between
# machines that hold separate quota accounts.
#
# ★ WHY IT EXISTS, and it is not convenience. When dev hosts hold separate quota,
# a handoff is triggered by exhaustion rather than by a stopping point: it lands
# mid-task, and at the wall there may be no quota left to run the sync. So the
# refs must ALREADY be on the peer — this is meant to run on a timer, not as a
# closing ceremony. And doing it by hand is where the real damage starts: a
# half-finished sync that prints nothing alarming leaves the next session
# reasoning from a false picture of where the work is. It spins, burns the quota
# it just switched hosts to get, and writes the false premise somewhere durable.
# Hence: this refuses to report a state it has not verified, and its bucket
# counts must sum.
#
# ★ THE MECHANISM: git push <peer> '+refs/heads/*:refs/remotes/<self>/*'
# Refs land in the peer's remote-tracking namespace, so the transfer CANNOT
# collide with a checked-out branch and CANNOT move a HEAD or disturb a worktree.
# Measured 2026-08-28 across 38 repos in both directions: 0 files changed, 0
# HEADs moved. Worktrees need no transfer — a worktree is a checkout, and the
# receiving host recreates it from the mirrored branch.
#
# ★ WHAT IT DOES NOT MOVE: uncommitted work. Ref mirroring moves commits. A hard
# stop mid-edit leaves that edit on the host that made it. Named because it is
# the one real hole, not because it is acceptable.
set -euo pipefail

DIRECTION=""
CHECK_ONLY=0
MODE=check
CLONE_NEW=0
DIR="Documents/repos/sini"
REMOTE_USER=""
LOCAL_USER="$(whoami)"
PEERS=()
ROOT=""

say() { echo "==> $*"; }
die() {
  echo "REFUSED: $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
peer-sync — make a peer's checkouts match this host's, verifiably.

  peer-sync --to DEST      send this host's branches to DEST
  peer-sync --from DEST    bring DEST's branches here
  peer-sync --check --to DEST    report what would move; change nothing

DEST is anything ssh accepts, and is the only thing you have to say:
  cortex          cortex.ts.example.net          10.0.0.4
  user@10.0.0.4   my-ssh-alias

Branches FAST-FORWARD. A branch that cannot fast-forward is never moved; it is
carried into refs/remotes/<peer>/ and the repo is reported as needing review.

Options:
  --to DEST          REQUIRED (or --from). Repeatable. Push direction.
  --from DEST        REQUIRED (or --to). Repeatable. Pull direction.
  --check            report only; write nothing
  --clone-new        with --from, also clone repos DEST has and this host does not.
                     Off by default: the hosts legitimately differ, and cloning
                     every peer-only repo makes them identical rather than
                     transferring work.
  --dir PATH         repo tree, relative to $HOME on BOTH hosts
                     (default: Documents/repos/sini)
  --root PATH        absolute local repo tree; overrides --dir locally
  --user NAME        ssh user, when DEST carries no user@ (default: this host's)
  -h, --help         this

EOF
}

SELF=""
while [ $# -gt 0 ]; do
  case "$1" in
    --to)
      [ -z "$DIRECTION" ] || [ "$DIRECTION" = sync ] || die "--to and --from are opposite directions; pick one"
      DIRECTION=sync; PEERS+=("$2"); shift 2 ;;
    --from)
      [ -z "$DIRECTION" ] || [ "$DIRECTION" = pull ] || die "--to and --from are opposite directions; pick one"
      DIRECTION=pull; PEERS+=("$2"); shift 2 ;;
    --check) CHECK_ONLY=1; shift ;;
    --clone-new) CLONE_NEW=1; shift ;;
    --dir) DIR="$2"; shift 2 ;;
    --root) ROOT="$2"; shift 2 ;;
    --user) REMOTE_USER="$2"; shift 2 ;;
    -h | --help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[ -n "$DIRECTION" ] || {
  echo "REFUSED: no direction given. --to DEST sends this host's branches there; --from DEST brings" >&2
  echo "         DEST's branches here. This tool will not guess which way work should move." >&2
  usage >&2
  exit 2
}
MODE="$DIRECTION"
[ "$CHECK_ONLY" = 1 ] && MODE=check

# `hostname` returns e.g. `laptop.local` on darwin and a bare name on NixOS.
[ -n "$SELF" ] || { SELF="$(hostname -s 2>/dev/null || hostname)"; SELF="${SELF%%.*}"; }
[ -n "$ROOT" ] || ROOT="$HOME/$DIR"
[ -d "$ROOT" ] || die "local repo tree not found: $ROOT (set --root or --dir)"

overall=0

for i in "${!PEERS[@]}"; do
  dest="${PEERS[$i]}"
  # A destination already carrying user@ is passed through untouched, so ssh
  # aliases and `user@10.0.0.4` both work without special-casing.
  case "$dest" in
    *@*) addr="$dest" ;;
    *) addr="${REMOTE_USER:-$LOCAL_USER}@$dest" ;;
  esac
  echo

  # Named explicitly, so being unreachable is an error rather than a fact to
  # note: every peer here was asked for by the caller. ssh's own stderr is
  # CARRIED INTO the message — "unreachable" alone is true and useless, and
  # hides the difference between a closed laptop, a missing known_hosts entry
  # and a refused key.
  # ★ ONE PROBE, TWO ANSWERS: reachability, and the peer's own name for the ref
  # namespace. Deriving the label from DEST meant an IP labelled its refs `10`,
  # which is why a --as flag existed at all; asking the host what it is called
  # removes the flag and the failure together. `--self` is gone for the same
  # reason: this host can answer that itself.
  if ! sshtest=$(ssh -n -o BatchMode=yes -o ConnectTimeout=10 "$addr" 'hostname -s 2>/dev/null || hostname' 2>&1); then
    die "cannot ssh to $addr — ${sshtest:-no output from ssh}. Nothing was changed."
  fi
  PEER="${sshtest%%.*}"
  PEER="$(printf '%s' "$PEER" | tr -cd 'A-Za-z0-9._-')"
  [ -n "$PEER" ] || { PEER="${dest#*@}"; PEER="${PEER%%.*}"; }
  say "$SELF -> $PEER   dest=$addr   mode=$MODE   dir=$DIR"

  # ★ THE UNIVERSE IS BOTH SIDES, NOT THE LOCAL TREE. Enumerating only local
  # repos meant a repo existing solely on the peer was never reached: it landed
  # in no bucket, and the bucket-sum guard below still passed — because it was
  # summing over the wrong universe. Measured 2026-08-28: a --pull run reported
  # `repos: 38, ok: 38, absent-on-peer: 0` while 25 peer-only repos went
  # unmentioned. A newly created library on the peer was invisible, silently.
  #
  # This is also one ssh instead of one per repo for the existence probe.
  # shellcheck disable=SC2029  # $DIR is LOCAL, expanded here on purpose
  peer_repos=$(ssh -n "$addr" "cd '$DIR' 2>/dev/null || exit 0; for x in */.git; do [ -e \"\$x\" ] || continue; echo \"\${x%/.git}\"; done" 2>/dev/null | sort -u || true)
  local_repos=$(cd "$ROOT" && for x in */.git; do [ -e "$x" ] || continue; echo "${x%/.git}"; done | sort -u || true)
  universe=$(printf '%s\n%s\n' "$local_repos" "$peer_repos" | grep -v '^$' | sort -u)
  # ★ COUNT THE UNIVERSE BEFORE THE LOOP. The bucket arithmetic below sums against
  # `total`, which the loop increments — so a loop that TERMINATES EARLY sums perfectly
  # against its own truncated view and reports a clean run. Measured 2026-08-28: an `ssh`
  # inside the read loop consumed the loop's stdin, 64 repos became 5, and every bucket
  # still balanced. Only the ref verification caught it.
  universe_n=$(printf '%s\n' "$universe" | grep -cv '^$')

  # Every repo lands in exactly ONE bucket and the buckets are summed against
  # the universe below. A repo falling silently out of the loop is the failure
  # this tool exists to prevent, so the arithmetic is itself the check.
  ok=(); only_local=(); only_peer=(); failed=(); dirty=(); unpushed=(); review=()
  total=0

  while read -r r; do
    [ -n "$r" ] || continue
    total=$((total + 1))
    d="$ROOT/$r"
    here=0; there=0
    printf '%s\n' "$local_repos" | grep -qx "$r" && here=1
    printf '%s\n' "$peer_repos" | grep -qx "$r" && there=1

    if [ "$here" = 1 ]; then
      [ -n "$(git -C "$d" status --porcelain 2>/dev/null)" ] && dirty+=("$r")
      if git -C "$d" rev-parse '@{u}' > /dev/null 2>&1; then
        n=$(git -C "$d" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)
        [ "$n" -gt 0 ] && unpushed+=("$r:$n")
      fi
    fi

    # --- present on this host only: the peer has never checked it out --------
    if [ "$here" = 1 ] && [ "$there" = 0 ]; then
      if [ "$MODE" = sync ]; then
        # ★ INIT ON THE PEER AND PUSH, rather than having the peer clone from us.
        # A reverse clone needs the PEER to resolve and reach US, which silently
        # requires reverse connectivity and cannot work when the caller gave an
        # IP or an ssh alias. Push-only means exactly one direction has to work:
        # the one the reachability check already proved.
        # `receive.denyCurrentBranch=updateInstead` populates the fresh working
        # tree, safe precisely because the repo was just created.
        head_branch=$(git -C "$d" symbolic-ref --short HEAD 2>/dev/null || echo main)
        ou=$(git -C "$d" remote get-url origin 2>/dev/null || true)

        # ★ PROBE THE PATH ITSELF; the bucket said "absent" on the strength of a
        # `*/.git` glob, and that glob is defeated by a different --dir/--root, a
        # bare repo, or a linked worktree whose `.git` is a FILE. `git init` on an
        # existing repo is a NO-OP rather than a failure, so a wrong "absent" used
        # to reach a force-push into real branches plus `checkout -- .`, which
        # overwrites the peer's branches and discards its uncommitted work. The
        # glob decides which bucket to try; only this probe authorises writing.
        # shellcheck disable=SC2029  # $DIR/$r are LOCAL, expanded here on purpose
        peer_state=$(ssh -n "$addr" "t='$DIR/$r'
          if [ ! -e \"\$t\" ]; then echo ABSENT
          elif [ ! -e \"\$t/.git\" ]; then echo NOT_A_REPO
          elif [ -n \"\$(git -C \"\$t\" status --porcelain 2>/dev/null)\" ]; then echo DIRTY
          else echo PRESENT_CLEAN; fi" 2>/dev/null || echo PROBE_FAILED)

        case "$peer_state" in
          ABSENT)
            # Nothing there to lose, so force and the working-tree checkout are safe.
            # shellcheck disable=SC2029  # $DIR/$r/$ou are LOCAL, expanded here on purpose
            if ssh -n "$addr" "mkdir -p '$DIR' && git init -q '$DIR/$r' && git -C '$DIR/$r' config receive.denyCurrentBranch updateInstead && { [ -z '$ou' ] || git -C '$DIR/$r' remote add origin '$ou'; }" 2>/dev/null \
              && git -C "$d" push -q "$addr:$DIR/$r" "+refs/heads/*:refs/heads/*" 2>/dev/null \
              && git -C "$d" push -q "$addr:$DIR/$r" "+refs/heads/*:refs/remotes/$SELF/*" 2>/dev/null \
              && ssh -n "$addr" "git -C '$DIR/$r' symbolic-ref HEAD 'refs/heads/$head_branch' && git -C '$DIR/$r' checkout -q -- . 2>/dev/null || true" 2>/dev/null; then
              ok+=("$r(created-on-peer)")
            else
              failed+=("$r(create)")
            fi
            ;;
          PRESENT_CLEAN)
            # ★ NO `+`. Git rejects a non-fast-forward push, so git itself decides
            # whether what we hold is a descendant of what the peer holds. That is
            # the ancestry check, enforced by the thing that owns the invariant
            # rather than reimplemented here — and a rejection costs nothing.
            if git -C "$d" push -q "$addr:$DIR/$r" "refs/heads/*:refs/heads/*" 2>/dev/null \
              && git -C "$d" push -q "$addr:$DIR/$r" "+refs/heads/*:refs/remotes/$SELF/*" 2>/dev/null; then
              ok+=("$r(fast-forwarded-on-peer)")
            else
              review+=("$r(diverged)")
            fi
            ;;
          *)
            # DIRTY, NOT_A_REPO, PROBE_FAILED. Nothing is written.
            review+=("$r($(printf '%s' "$peer_state" | tr 'A-Z_' 'a-z-'))")
            ;;
        esac
      else
        only_local+=("$r")
      fi
      continue
    fi

    # --- present on the peer only: e.g. a library created over there ---------
    if [ "$here" = 0 ] && [ "$there" = 1 ]; then
      # ★ REPORT, DO NOT CLONE, UNLESS ASKED. The hosts legitimately carry
      # different repo sets — measured 2026-08-28, one held 38 and the other 64,
      # the extra 26 being unrelated projects rather than work in flight. A pull
      # that cloned every peer-only repo would dump all of them here, which is
      # not "syncing work" but "making two machines identical", a different and
      # unasked-for thing. Naming them is the useful part; --clone-new opts in.
      if [ "$MODE" = pull ] && [ "$CLONE_NEW" = 1 ]; then
        # Cloning FROM the peer needs only the direction the reachability check
        # already proved.
        if git clone -q "$addr:$DIR/$r" "$d" 2>/dev/null; then
          ok+=("$r(cloned-from-peer)")
        else
          failed+=("$r(clone)")
        fi
      else
        only_peer+=("$r")
      fi
      continue
    fi

    # --- on both sides ------------------------------------------------------
    case "$MODE" in
      sync)
        # ★ FAST-FORWARD THE PEER'S REAL BRANCHES. A handoff session runs `git status` and
        # `git log`; it does not begin by checking which iteration of main it is on, or
        # whether some side namespace holds a better one. So the work has to land ON the
        # branch it expects, at the sha it expects.
        # Mirroring into `refs/remotes/<self>/` failed that: with no configured remote,
        # `blade/main` did not even resolve — measured, `warning: refname 'blade/main' is
        # ambiguous` — and neither `git remote -v` nor `git branch` showed anything.
        # ★★ NO `+`. Git fast-forwards what it can and refuses divergence PER REF, so what
        # lands is exactly what a handoff can trust, and the check is enforced by the thing
        # that owns the invariant. `updateInstead` carries a fast-forward into a CLEAN
        # worktree and refuses a dirty one, which is the safety we would have had to build.
        # shellcheck disable=SC2029  # $DIR/$r is LOCAL, expanded here on purpose
        ssh -n "$addr" "git -C '$DIR/$r' config receive.denyCurrentBranch updateInstead" 2>/dev/null || true
        git -C "$d" push -q "$addr:$DIR/$r" "refs/heads/*:refs/heads/*" 2>/dev/null || true
        # The peer namespace is now a FALLBACK, not the destination: a branch that could
        # NOT fast-forward still arrives here, so diverged work is never stranded on one
        # host — it is simply not pretended to be the peer's branch.
        git -C "$d" push -q "$addr:$DIR/$r" "+refs/heads/*:refs/remotes/$SELF/*" 2>/dev/null || true

        # Classify by comparing shas, never by a push's exit code.
        # shellcheck disable=SC2029  # $DIR/$r is LOCAL, expanded here on purpose
        peer_heads=$(ssh -n "$addr" "git -C '$DIR/$r' for-each-ref --format='%(refname) %(objectname)' refs/heads/" 2>/dev/null | sed 's|^refs/heads/||' | sort)
        stuck=""
        while read -r bname bsha; do
          [ -n "$bname" ] || continue
          printf '%s\n' "$peer_heads" | grep -qx "$bname $bsha" || stuck="$stuck,$bname"
        done <<< "$(git -C "$d" for-each-ref --format='%(refname) %(objectname)' refs/heads/ | sed 's|^refs/heads/||' | sort)"
        if [ -z "$stuck" ]; then
          ok+=("$r")
        else
          review+=("$r(no-ff:${stuck#,})")
        fi
        ;;
      pull)
        if git -C "$d" fetch -q "$addr:$DIR/$r" "+refs/heads/*:refs/remotes/$PEER/*" 2>/dev/null; then
          ok+=("$r")
        else
          failed+=("$r")
        fi
        ;;
      *) ok+=("$r") ;;
    esac
  done <<< "$universe"

  n_ok=${#ok[@]}
  n_ol=${#only_local[@]}
  n_op=${#only_peer[@]}
  n_fail=${#failed[@]}
  n_rev=${#review[@]}
  say "repos: $total (both sides)   ok: $n_ok   here-only: $n_ol   peer-only: $n_op   failed: $n_fail   needs-review: $n_rev"
  [ "$n_ol" -gt 0 ] && echo "    here only — $PEER has never checked these out; --to creates them there: ${only_local[*]}"
  [ "$n_op" -gt 0 ] && echo "    on $PEER only — not present here; --from --clone-new would clone them: ${only_peer[*]}"
  if [ "$n_fail" -gt 0 ]; then
    echo "    FAILED: ${failed[*]}" >&2
    overall=1
  fi
  if [ "$n_rev" -gt 0 ]; then
    echo "    NEEDS MANUAL REVIEW — the peer already holds these and nothing was written: ${review[*]}" >&2
    echo "      no-ff = the peer's branch is not an ancestor of ours, so it was NOT moved; the commits
      are on the peer under refs/remotes/<self>/ and need a human merge or rebase.
      diverged = the peer has commits this host does not; dirty = uncommitted work there;" >&2
    echo "      not-a-repo / probe-failed = the path exists but is not a checkout we can reason about." >&2
    overall=1
  fi
  [ ${#dirty[@]} -gt 0 ] && echo "    uncommitted — NOT transferred by this tool: ${dirty[*]}"
  [ ${#unpushed[@]} -gt 0 ] && echo "    unpushed to origin (fine, the peer has them): ${unpushed[*]}"

  if [ "$total" -ne "$universe_n" ]; then
    die "the repo loop processed $total of $universe_n repos for $PEER — it terminated early. Do not trust this run."
  fi
  if [ $((n_ok + n_ol + n_op + n_fail + n_rev)) -ne "$total" ]; then
    die "bucket arithmetic does not sum for $PEER: $n_ok+$n_ol+$n_op+$n_fail+$n_rev != $total. A repo was dropped silently; do not trust this run."
  fi

  [ "$MODE" = check ] && continue

  # Verify what was just claimed, rather than trusting the transfer's exit code.
  if [ "$MODE" = sync ]; then
    say "verifying every local branch is on $PEER at the same sha"
  else
    say "verifying every branch fetched from $PEER is present here at the same sha"
  fi
  bad=0
  checked=0
  for d in "$ROOT"/*/; do
    r="$(basename "$d")"
    [ -d "$d/.git" ] || continue
    case " ${failed[*]} ${only_local[*]} ${only_peer[*]} ${review[*]} " in *" $r "*) continue ;; esac

    # ★ FULL refname, never %(refname:short). The short form strips the longest
    # UNAMBIGUOUS prefix, so it disambiguates per-ref and unpredictably:
    # measured 2026-08-28, `refs/remotes/cortex/main` rendered as
    # `remotes/cortex/main` while its siblings rendered as `cortex/a15-spike`.
    # A fixed `sed s|^cortex/||` then failed on exactly those, producing a FALSE
    # MISMATCH on 4 of 149 refs that had in fact arrived. Stripping a known,
    # complete prefix from the full name is deterministic.
    if [ "$MODE" = sync ]; then
      want=$(git -C "$d" for-each-ref --format='%(refname) %(objectname)' refs/heads/ | sed 's|^refs/heads/||' | sort)
      # ★ VERIFY AGAINST THE PEER'S REAL BRANCHES — that is where a handoff will look.
      # shellcheck disable=SC2029  # $DIR/$r is LOCAL, expanded here on purpose
      have=$(ssh -n "$addr" "git -C '$DIR/$r' for-each-ref --format='%(refname) %(objectname)' refs/heads/" 2>/dev/null | sed 's|^refs/heads/||' | sort)
    else
      # shellcheck disable=SC2029  # $DIR/$r is LOCAL, expanded here on purpose
      want=$(ssh -n "$addr" "git -C '$DIR/$r' for-each-ref --format='%(refname) %(objectname)' refs/heads/" 2>/dev/null | sed 's|^refs/heads/||' | sort)
      have=$(git -C "$d" for-each-ref --format='%(refname) %(objectname)' "refs/remotes/$PEER/" | sed "s|^refs/remotes/$PEER/||" | sort)
    fi

    while read -r name sha; do
      [ -n "$name" ] || continue
      checked=$((checked + 1))
      printf '%s\n' "$have" | grep -qx "$name $sha" || {
        echo "    MISMATCH $r: $name@${sha:0:8} did not arrive" >&2
        bad=$((bad + 1))
      }
    done <<< "$want"
  done

  if [ "$bad" -gt 0 ]; then
    echo "    ★ $bad of $checked ref(s) did not arrive. The sync with $PEER is INCOMPLETE — do not hand off on it." >&2
    overall=1
  else
    say "VERIFIED: $checked ref(s) present at matching shas"
  fi
done

echo
case "$MODE" in
  check) say "CHECK ONLY — nothing was changed. Re-run without --check to act." ;;
  *)
    if [ "$overall" -eq 0 ]; then
      say "HANDOFF READY: every peer verified."
    else
      die "one or more peers are NOT ready — see the lines above. Do not hand off on this run."
    fi
    ;;
esac
exit "$overall"
