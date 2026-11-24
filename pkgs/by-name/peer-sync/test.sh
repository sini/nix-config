#!/usr/bin/env bash
# shellcheck disable=SC2329  # helpers and scenarios are invoked through A/control
# peer-sync fixture test, run by the nix check `peer-sync` (peer-sync-check.nix).
#   bash test.sh <peer-sync binary> <peer-sync.py source>
#
# No network and no sshd: a fake `ssh` first on PATH runs each remote command
# locally, with HOME set to a second fixture tree (the "peer"). It refuses any
# non-master call that does not ride the control socket, so the one-connection
# property is checked too.
#
# Every case asserts the reported bucket AND the resulting refs. Each case has a
# control: a run whose behaviour is deliberately wrong (a mutant of the tool, or
# the fixture with the fault removed), in which the named assertion must FAIL.
set -uo pipefail

TOOL_BIN=$1
SRC=$2
W=$(mktemp -d)
LR=$W/local/Documents/repos/sini
PR=$W/peer/Documents/repos/sini
mkdir -p "$W/bin" "$W/peerbin"

export GIT_CONFIG_GLOBAL=$W/gitconfig GIT_CONFIG_NOSYSTEM=1
cat > "$GIT_CONFIG_GLOBAL" << 'EOF'
[user]
	name = t
	email = t@example.invalid
[init]
	defaultBranch = main
[advice]
	detachedHead = false
EOF

BASH_BIN=$(command -v bash)
cat > "$W/bin/ssh" << EOF
#!$BASH_BIN
master=0; ctl=0; op=""
while [ \$# -gt 0 ]; do
  case "\$1" in
    -M) master=1; shift ;;
    -O) op=\$2; shift 2 ;;
    -S) ctl=1; shift 2 ;;
    -o) case "\$2" in ControlPath=*) ctl=1 ;; esac; shift 2 ;;
    -p|-l|-i|-F|-E|-b|-c|-D|-L|-R|-W|-J) shift 2 ;;
    --) shift; break ;;
    -*) shift ;;
    *) break ;;
  esac
done
host=\$1; shift
cmd="\$*"
printf 'master=%s ctl=%s op=%s host=%s cmd=%s\n' "\$master" "\$ctl" "\$op" "\$host" "\${cmd%%\$'\n'*}" >> "$W/ssh.log"
[ -z "\$op" ] || exit 0
[ "\$master" = 0 ] || exit 0
[ "\$ctl" = 1 ] || { echo "fake ssh: a call without the control socket" >&2; exit 255; }
case "\$cmd" in
  *receive-pack*) [ -n "\${FAKE_SSH_STALL:-}" ] && case "\$cmd" in *"\$FAKE_SSH_STALL"*) sleep 600 ;; esac ;;
esac
cd "$W/peer" || exit 255
export HOME="$W/peer" FAKE_REMOTE=1 PATH="$W/peerbin:\$PATH"
exec sh -c "\$cmd"
EOF
cat > "$W/bin/ssh-add" << EOF
#!$BASH_BIN
case "\${FAKE_SSH_ADD_HANG:-}" in
  local) [ -n "\${FAKE_REMOTE:-}" ] || sleep 600 ;;
  peer) [ -z "\${FAKE_REMOTE:-}" ] || sleep 600 ;;
esac
echo "The agent has no identities."
exit 1
EOF
printf '#!%s\necho peerhost\n' "$BASH_BIN" > "$W/peerbin/hostname"
chmod +x "$W/bin/ssh" "$W/bin/ssh-add" "$W/peerbin/hostname"
export PATH="$W/bin:$PATH"
export PEER_SYNC_OP_TIMEOUT=5 PEER_SYNC_HEARTBEAT=1 PEER_SYNC_PROBE_TIMEOUT=10 PEER_SYNC_AGENT_TIMEOUT=2
export SSH_AUTH_SOCK=$W/agent.sock
unset FAKE_SSH_STALL FAKE_SSH_ADD_HANG
# The receive-pack command the fake ssh stalls on: the `stall` repo's push.
STALL="sini/stall'"

# ---------------------------------------------------------------- helpers
RES=/dev/null
A() {
  local name=$1
  shift
  if "$@"; then echo "PASS $name" >> "$RES"; else echo "FAIL $name" >> "$RES"; fi
}
not() { ! "$@"; }
sha() { git -C "$1" rev-parse -q --verify "$2" 2> /dev/null || echo none; }
eq() { [ "$1" = "$2" ]; }
has() { grep -qE -- "$1" "$OUT"; }
fresh() {
  rm -rf "$W/local" "$W/peer" "$W/origin" "$W/ssh.log"
  mkdir -p "$LR" "$PR" "$W/origin"
  touch "$W/ssh.log"
}
mkorigin() {
  local s=$W/seed-$1
  git init -q --bare "$W/origin/$1.git"
  git init -q "$s"
  echo base > "$s/f"
  git -C "$s" add f
  git -C "$s" commit -qm base
  git -C "$s" push -q "$W/origin/$1.git" main
  rm -rf "$s"
}
clone() { git clone -q "$W/origin/$2.git" "$1/$2"; }
commit() {
  echo "$2" > "$1/f"
  git -C "$1" commit -qam "$2"
}
# Run the tool under test (array TOOL) into $OUT; rc into $RC.
runtool() {
  (cd "$W" && HOME=$W/local timeout 120 "${TOOL[@]}" "$@") > "$OUT" 2>&1
  RC=$?
  SELF=$(sed -nE 's/^==> ([^ ]+) -> peerhost .*/\1/p' "$OUT" | head -n1)
}
# What a --check run must leave identical: every peer repo's refs, config, files.
snap() {
  (
    cd "$PR" || exit 0
    for r in */; do
      echo "== $r"
      git -C "$r" for-each-ref --format='%(refname) %(objectname)'
      cat "$r/.git/config"
      cat "$r/f" 2> /dev/null
      git -C "$r" status --porcelain
    done
  )
}

# ---------------------------------------------------------------- scenarios
# Main --to scenario, -j 2: ff, diverged, dirty, absent (created), absent (skipped),
# already equal, peer-only, and a push that stalls past the per-op timeout.
setup_main() {
  fresh
  for r in ff div dirty same stall; do
    mkorigin "$r"
    clone "$LR" "$r"
    clone "$PR" "$r"
  done
  for r in new skip; do mkorigin "$r"; clone "$LR" "$r"; done
  mkorigin peeronly
  clone "$PR" peeronly
  commit "$LR/ff" l1
  commit "$LR/div" L
  commit "$PR/div" P
  commit "$LR/dirty" x
  echo uncommitted > "$PR/dirty/f"
  commit "$LR/new" n1
  commit "$LR/stall" s1
  BASE_DIRTY=$(sha "$PR/dirty" main)
  P_DIV=$(sha "$PR/div" main)
  P_STALL=$(sha "$PR/stall" main)
}
scenario_main() {
  setup_main
  OUT=$W/out.main
  FAKE_SSH_STALL=$STALL runtool --to peerhost -j 2
  A "main: exits 1 (review and failure present)" eq "$RC" 1
  A "ff: bucket ok" has '^\[[0-9]+/8\] ff: push main -> ok \('
  A "ff: peer main fast-forwarded to ours" eq "$(sha "$PR/ff" main)" "$(sha "$LR/ff" main)"
  A "ff: peer worktree updated (updateInstead)" eq "$(cat "$PR/ff/f")" l1
  A "ff: fallback refs/remotes/<self>/main written" eq "$(sha "$PR/ff" "refs/remotes/$SELF/main")" "$(sha "$LR/ff" main)"
  A "div: bucket needs-review no-ff" has '^\[[0-9]+/8\] div: .* -> needs-review: no-ff:main '
  A "div: peer main untouched" eq "$(sha "$PR/div" main)" "$P_DIV"
  A "div: our main carried to refs/remotes/<self>/main" eq "$(sha "$PR/div" "refs/remotes/$SELF/main")" "$(sha "$LR/div" main)"
  A "dirty: bucket needs-review dirty" has '^\[[0-9]+/8\] dirty: .* -> needs-review: dirty '
  A "dirty: peer main untouched" eq "$(sha "$PR/dirty" main)" "$BASE_DIRTY"
  A "dirty: nothing written (no refs/remotes/<self>)" eq "$(git -C "$PR/dirty" for-each-ref "refs/remotes/$SELF/")" ""
  A "dirty: uncommitted edit intact" eq "$(cat "$PR/dirty/f")" uncommitted
  A "new: bucket ok created-on-peer" has '^\[[0-9]+/8\] new: create on peerhost.* -> ok: created-on-peer '
  A "new: peer main equals ours" eq "$(sha "$PR/new" main)" "$(sha "$LR/new" main)"
  A "new: peer worktree populated and clean" eq "$(cat "$PR/new/f" 2> /dev/null)$(git -C "$PR/new" status --porcelain 2>&1)" n1
  A "new: upstream set on peer" eq "$(git -C "$PR/new" config branch.main.remote 2> /dev/null)" origin
  A "skip: bucket skipped not-in-transit" has '^\[[0-9]+/8\] skip: absent on peerhost -> skipped: not-in-transit '
  A "skip: nothing created on peer" not test -e "$PR/skip"
  A "same: bucket ok up to date" has '^\[[0-9]+/8\] same: up to date -> ok \('
  A "peeronly: bucket peer-only" has '^\[[0-9]+/8\] peeronly: on peerhost only -> peer-only '
  A "stall: bucket failed, timeout named" has '^\[[0-9]+/8\] stall: push main -> failed: push timed out after 5s '
  A "stall: heartbeat printed" has '^    … still pushing stall \([0-9]+s\)$'
  A "stall: peer main untouched" eq "$(sha "$PR/stall" main)" "$P_STALL"
  A "j2: one line per repo" eq "$(grep -cE '^\[[0-9]+/8\] ' "$OUT")" 8
  A "j2: each repo exactly once" eq "$(sed -nE 's/^\[[0-9]+\/8\] ([^:]+):.*/\1/p' "$OUT" | sort | tr '\n' ' ')" "dirty div ff new peeronly same skip stall "
  A "j2: counters 1..8 each once" eq "$(sed -nE 's/^\[([0-9]+)\/8\].*/\1/p' "$OUT" | sort -n | tr '\n' ' ')" "1 2 3 4 5 6 7 8 "
  A "j2: no line interleaved" eq "$(grep -E '\[[0-9]+/8\]' "$OUT" | grep -cvE '^\[[0-9]+/8\] ')" 0
  A "j2: buckets sum to the universe" has '^==> repos: 8 \(both sides\)   ok: 3   here-only: 0   peer-only: 1   skipped: 1   failed: 1   needs-review: 2$'
  A "j2: arithmetic guard silent" not has 'does not sum|terminated early'
  A "verify: ok repos re-read and verified" has '^==> VERIFIED: [0-9]+ ref\(s\) present at matching shas$'
  A "ssh: exactly one handshake (master)" eq "$(grep -c '^master=1' "$W/ssh.log")" 1
  A "ssh: every other call rode the socket" eq "$(grep -v '^master=1' "$W/ssh.log" | grep -cv 'ctl=1')" 0
}

# --check writes nothing, and predicts the buckets.
scenario_check() {
  setup_main
  local before
  before=$(snap)
  OUT=$W/out.check
  runtool --check --to peerhost -j 2
  A "check: peer byte-identical after --check" eq "$(snap)" "$before"
  A "check: diverged predicted" has '^\[[0-9]+/8\] div: would push main -> needs-review: would-not-ff:main '
  A "check: absent+in-transit predicted here-only" has '^\[[0-9]+/8\] new: .* -> here-only: would create'
  A "check: says CHECK ONLY" has '^==> CHECK ONLY'
  # Control: the same fixture after a real run must NOT be identical, so the
  # snapshot is sensitive to the writes it claims are absent.
  OUT=$W/out.check-control
  runtool --to peerhost -j 2
  A "check-control: a real run changes the snapshot" not eq "$(snap)" "$before"
}

# --from: ff of this host's branches, peer-only with and without --clone-new.
setup_pull() {
  fresh
  mkorigin pullff
  clone "$LR" pullff
  clone "$PR" pullff
  commit "$PR/pullff" p1
  mkorigin peernew
  clone "$PR" peernew
  commit "$PR/peernew" q1
  mkorigin localonly
  clone "$LR" localonly
}
scenario_pull() {
  setup_pull
  OUT=$W/out.pull
  runtool --from peerhost
  A "pull: exits 0" eq "$RC" 0
  A "pull ff: bucket ok" has '^\[[0-9]+/3\] pullff: fetch main -> ok \('
  A "pull ff: our main fast-forwarded" eq "$(sha "$LR/pullff" main)" "$(sha "$PR/pullff" main)"
  A "pull ff: our worktree updated" eq "$(cat "$LR/pullff/f")" p1
  A "pull ff: fallback refs/remotes/peerhost/main" eq "$(sha "$LR/pullff" refs/remotes/peerhost/main)" "$(sha "$PR/pullff" main)"
  A "pull localonly: bucket here-only" has '^\[[0-9]+/3\] localonly: .* -> here-only '
  A "pull no --clone-new: bucket peer-only" has '^\[[0-9]+/3\] peernew: on peerhost only -> peer-only '
  A "pull no --clone-new: nothing cloned" not test -e "$LR/peernew"
  A "pull: buckets sum" has '^==> repos: 3 \(both sides\)   ok: 1   here-only: 1   peer-only: 1   skipped: 0   failed: 0   needs-review: 0$'
  # The pair is each other's control: same fixture, the flag flips the outcome.
  OUT=$W/out.pull-clone
  runtool --from peerhost --clone-new
  A "pull --clone-new: bucket ok cloned-from-peer" has '^\[[0-9]+/3\] peernew: clone from peerhost -> ok: cloned-from-peer '
  A "pull --clone-new: our main equals the peer's" eq "$(sha "$LR/peernew" main)" "$(sha "$PR/peernew" main)"
  A "pull --clone-new: verified" has '^==> HANDOFF READY'
}

# Pre-flight agent checks. FAKE_SSH_ADD_HANG=local|peer makes that side's ssh-add sleep.
scenario_agent() {
  local before
  setup_main
  before=$(snap)
  OUT=$W/out.agent-local
  FAKE_SSH_ADD_HANG=local runtool --to peerhost
  A "agent local: named diagnosis" has "agent socket $W/agent.sock hangs"
  A "agent local: says how to fix" has 'systemctl --user restart ssh-agent-mux'
  A "agent local: refused, exit 1" eq "$RC" 1
  A "agent local: before any network (no ssh call)" eq "$(wc -l < "$W/ssh.log")" 0
  OUT=$W/out.agent-peer
  FAKE_SSH_ADD_HANG=peer runtool --to peerhost
  A "agent peer: named diagnosis" has 'the ssh agent on [^ ]*peerhost hangs'
  A "agent peer: nothing written" eq "$(snap)" "$before"
  # Control: no hang -> no diagnosis, and the run goes on to verify.
  OUT=$W/out.agent-none
  runtool --to peerhost
  A "agent none: no diagnosis" not has 'hangs'
  A "agent none: run proceeds to verification" has '^==> VERIFIED'
}

run_all() {
  RES=$1
  : > "$RES"
  scenario_main
  scenario_check
  scenario_pull
  scenario_agent
}

# ---------------------------------------------------------------- the real tool
TOOL=("$TOOL_BIN")
run_all "$W/res.real"
cat "$W/res.real"
status=0
if grep -q '^FAIL' "$W/res.real"; then
  echo "peer-sync: assertions FAILED against the real tool" >&2
  for f in "$W"/out.*; do
    echo "----- $f" >&2
    cat "$f" >&2
  done
  status=1
fi

# ---------------------------------------------------------------- controls
# Each control breaks one behaviour and requires the named assertion to FAIL.
# A mutant whose edit did not apply is itself an error (it would test nothing).
NMUT=0
mutant() { # dest, python-replace-from, to; fails if the edit does not apply
  python3 - "$SRC" "$1" "$2" "$3" << 'EOF'
import sys
src, dst, a, b = sys.argv[1:]
s = open(src).read()
if a not in s:
    sys.exit(f"mutant edit does not apply: {a!r}")
open(dst, "w").write(s.replace(a, b, 1))
EOF
}
expect_fail() { # results-file, assertion name, description
  if grep -qxF "FAIL $2" "$1"; then
    echo "CONTROL OK   [$3] -> FAIL $2"
  else
    echo "CONTROL MISSED [$3]: '$2' did not fail" >&2
    status=1
  fi
}
control() { # description, scenario, assertion, mutant-from, mutant-to
  local m
  NMUT=$((NMUT + 1))
  m=$W/mutant-$NMUT.py
  mutant "$m" "$4" "$5" || {
    echo "CONTROL BROKEN [$1]: mutant did not apply" >&2
    status=1
    return
  }
  TOOL=(python3 "$m")
  RES=$W/res.ctl
  : > "$RES"
  "$2"
  expect_fail "$RES" "$3" "$1"
}

control "force-push heads" scenario_main "div: peer main untouched" \
  'self.refspecs(heads, force=False)' 'self.refspecs(heads, force=True)'
control "push into a dirty peer" scenario_main "dirty: nothing written (no refs/remotes/<self>)" \
  'if st != "CLEAN":' 'if st not in ("CLEAN", "DIRTY"):'
control "no updateInstead on receive-pack" scenario_main "ff: peer main fast-forwarded to ours" \
  'receive_pack="git -c receive.denyCurrentBranch=updateInstead receive-pack"' 'receive_pack=None'
control "skip predicate disabled" scenario_main "skip: nothing created on peer" \
  'if not in_transit(d):' 'if False:'
control "create disabled (absent repo skipped)" scenario_main "new: peer main equals ours" \
  'if not in_transit(d):' 'if True:'
control "a repo's line not printed" scenario_main "j2: one line per repo" \
  '            emit(
                f"[{total}/{universe_n}]' '            oc.repo == "same" or emit(
                f"[{total}/{universe_n}]'
control "a repo dropped from the buckets" scenario_main "j2: arithmetic guard silent" \
  'buckets[oc.bucket].append(oc)' 'oc.repo == "same" or buckets[oc.bucket].append(oc)'
control "no local agent pre-flight" scenario_agent "agent local: named diagnosis" \
  '        local_agent_check()
' '        pass
'
control "pull ff of the checked-out branch disabled" scenario_pull "pull ff: our main fast-forwarded" \
  '"merge", "--ff-only", "-q", psha' '"merge", "--ff-only", "-q", "HEAD"'

# Timeout control: the same fixture with no stall; the stall assertions must fail.
TOOL=("$TOOL_BIN")
RES=$W/res.ctl
: > "$RES"
STALL=never-matches-anything
scenario_main
expect_fail "$RES" "stall: bucket failed, timeout named" "no stall in the fixture"

exit "$status"
