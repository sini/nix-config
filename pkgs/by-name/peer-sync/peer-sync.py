#!/usr/bin/env python3
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
# ★ THE MECHANISM, BOTH DIRECTIONS: the peer's (or this host's) REAL branches are
# fast-forwarded, and refs/remotes/<other>/ is the FALLBACK that catches whatever
# could not. A handoff session runs `git status` and `git log`; it does not look in
# a side namespace, so work that lands only there has not arrived in any sense the
# next session can act on. Divergence is never forced and never stranded: git owns
# the ancestry test in both arms, and what it refuses is reported for review.
# Worktrees need no transfer — a worktree is a checkout, and the receiving host
# recreates it from the mirrored branch.
#
# ★ WHAT IT DOES NOT MOVE: uncommitted work. Ref mirroring moves commits. A hard
# stop mid-edit leaves that edit on the host that made it. Named because it is
# the one real hole, not because it is acceptable.
#
# ★ v2: WHY A RUN USED TO "SIT FOREVER". Measured 2026-11-23 from bitstream: ~160
# local-only clone dirs each got `git init` plus a full push, every repo cost 4–6
# separate ssh handshakes, every push was `-q 2>/dev/null`, the peer fetched origin
# serially per repo, and nothing printed until the final summary. So v2 holds ONE
# ssh connection per peer (ControlMaster), probes every repo's state and heads in
# ONE remote call, skips dirs that carry no work in transit, bounds every push and
# fetch with its own timeout, runs repos in parallel (-j), and prints a line per
# repo as it completes plus a heartbeat during a long push.
#
# ★ CLONES SHARING AN ORIGIN ARE NOT DEDUPED into one peer repo. Each clone dir is
# its own checkout with its own `main`; folding several into a "primary" clone would
# need renamed branches (refs/heads/<dir>/main), which breaks the rule that work
# lands on the branch a handoff expects, makes the bucket and verification per-dir
# rather than per-repo, and lets one clone's fast-forward refuse another's. The skip
# predicate already removes the scale problem: a clone with nothing local-only is
# not transferred at all.
#
# ★ THE REMOTE SIDE IS JUST `ssh` ON PATH. Every remote action is `ssh ... sh -s`
# with the script on stdin, and git reaches the peer through GIT_SSH_COMMAND=ssh.
# Swapping `ssh` on PATH for a wrapper that runs the command locally against a
# second tree is how the check (peer-sync-check.nix) exercises it with no network.
import fnmatch
import getpass
import os
import shlex
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed


def env_int(name, default):
    v = os.environ.get(name, "")
    if not v:
        return default
    try:
        return int(v)
    except ValueError:
        print(
            f"REFUSED: {name}={v!r} is not an integer number of seconds",
            file=sys.stderr,
        )
        sys.exit(2)


# ★★★ SSH'S OWN TIMEOUT COVERS THE WRONG HALF. `ConnectTimeout` bounds the TCP
# connect ONLY. Measured 2026-08-30: a hostname whose DNS pointed at a CDN edge
# rather than at the host ACCEPTED the connect and then never spoke SSH — so
# ConnectTimeout could not fire, and the probe hung with no output. The tool read
# as "stalling" while the network behaved exactly as configured. A wall-clock bound
# on the WHOLE call is the only thing that catches a PRE-AUTH stall;
# ServerAlive* bounds the post-auth half and is structurally blind to this one.
# Both are needed, and neither substitutes for the other.
PROBE_TIMEOUT = env_int("PEER_SYNC_PROBE_TIMEOUT", 20)
# Every push, fetch, clone and remote call after the connect carries this bound, so
# one stalled repo fails with a named reason and the run goes on.
OP_TIMEOUT = env_int("PEER_SYNC_OP_TIMEOUT", 300)
# `ssh-add -l` answers in milliseconds from a live agent; a wedged one never does.
AGENT_TIMEOUT = env_int("PEER_SYNC_AGENT_TIMEOUT", 5)
HEARTBEAT = env_int("PEER_SYNC_HEARTBEAT", 15)

# ★ BatchMode ON EVERY CALL, not just the probe. Without it a host that has
# dropped our key drops to an interactive password prompt and the run hangs
# there — the same stall wearing a different cause.
SSH_OPTS = [
    "-o",
    "BatchMode=yes",
    "-o",
    "ConnectTimeout=10",
    "-o",
    "ServerAliveInterval=5",
    "-o",
    "ServerAliveCountMax=3",
]

DEFAULT_DIR = "Documents/repos/sini"
BUCKETS = ["ok", "here-only", "peer-only", "skipped", "failed", "needs-review"]

_out = threading.Lock()
_live = set()
_live_lock = threading.Lock()


class Refused(Exception):
    pass


def die(msg):
    raise Refused(msg)


def emit(msg, err=False):
    # One write per line under one lock: parallel jobs never interleave mid-line.
    with _out:
        f = sys.stderr if err else sys.stdout
        f.write(msg + "\n")
        f.flush()


def say(msg):
    emit("==> " + msg)


class Result:
    def __init__(self, rc, out, err, elapsed):
        self.rc, self.out, self.err, self.elapsed = rc, out, err, elapsed

    @property
    def timed_out(self):
        return self.rc == 124

    def last_err(self):
        lines = [x for x in self.err.splitlines() if x.strip()]
        return lines[-1].strip() if lines else f"exit {self.rc}"


def _kill(p):
    for sig in (signal.SIGTERM, signal.SIGKILL):
        try:
            os.killpg(p.pid, sig)
        except ProcessLookupError:
            return
        try:
            p.wait(timeout=2)
            return
        except subprocess.TimeoutExpired:
            continue


def run(cmd, timeout, label=None, stdin=None, env=None):
    """Run cmd with a wall-clock bound over the WHOLE call. rc 124 = timed out.

    The child gets its own process group so a timeout takes down git AND the ssh
    it spawned. Output goes to files, not pipes, so a backgrounded ssh master
    holding an fd cannot wedge the read.
    """
    t0 = time.monotonic()
    with tempfile.TemporaryFile() as fo, tempfile.TemporaryFile() as fe:
        p = subprocess.Popen(
            cmd,
            stdin=subprocess.PIPE if stdin is not None else subprocess.DEVNULL,
            stdout=fo,
            stderr=fe,
            env=env,
            start_new_session=True,
        )
        with _live_lock:
            _live.add(p)
        try:
            if stdin is not None:
                try:
                    p.stdin.write(stdin.encode())
                    p.stdin.close()
                except BrokenPipeError:
                    pass
            rc = None
            while rc is None:
                left = timeout - (time.monotonic() - t0)
                if left <= 0:
                    _kill(p)
                    rc = 124
                    break
                try:
                    rc = p.wait(timeout=min(left, HEARTBEAT) if label else left)
                except subprocess.TimeoutExpired:
                    el = time.monotonic() - t0
                    if label and el < timeout:
                        emit(f"    … still {label} ({int(el)}s)")
        finally:
            with _live_lock:
                _live.discard(p)
        fo.seek(0)
        fe.seek(0)
        out = fo.read().decode(errors="replace")
        err = fe.read().decode(errors="replace")
    return Result(rc, out, err, time.monotonic() - t0)


def kill_live():
    with _live_lock:
        procs = list(_live)
    for p in procs:
        _kill(p)


def git(d, *args):
    """A LOCAL git read or write: no network, so no heartbeat."""
    return run(["git", "-C", d, *args], OP_TIMEOUT)


def parse_heads(text):
    # ★ FULL refname, never %(refname:short). The short form strips the longest
    # UNAMBIGUOUS prefix, so it disambiguates per-ref and unpredictably:
    # measured 2026-08-28, `refs/remotes/cortex/main` rendered as
    # `remotes/cortex/main` while its siblings rendered as `cortex/a15-spike`.
    # A fixed strip then failed on exactly those, producing a FALSE MISMATCH on 4
    # of 149 refs that had in fact arrived. Stripping a known, complete prefix
    # from the full name is deterministic.
    heads = {}
    for line in text.splitlines():
        if " " not in line:
            continue
        name, sha = line.rsplit(" ", 1)
        for prefix in ("refs/heads/",):
            if name.startswith(prefix):
                heads[name[len(prefix) :]] = sha
    return heads


def local_heads(d, ns="refs/heads/"):
    r = git(d, "for-each-ref", "--format=%(refname) %(objectname)", ns)
    heads = {}
    for line in r.out.splitlines():
        if " " in line:
            name, sha = line.rsplit(" ", 1)
            if name.startswith(ns):
                heads[name[len(ns) :]] = sha
    return heads


# One remote call returns every repo's state and heads. Argument 1 is `all` (also
# enumerate the peer's own */.git, so peer-only repos enter the universe) or
# `listed`; argument 2 is the tree; the rest are the repo names to probe BY PATH.
# Output, tab-separated, parsed by Probe below:
#   H <hostname>
#   R <repo> <ABSENT|NOT_A_REPO|BROKEN|DIRTY|CLEAN>
#   C <repo> <current branch>          (present repos with a branch checked out)
#   B <repo> <branch> <sha>            (one per refs/heads/* entry)
#   END                                (absent => the output was truncated)
PROBE_SCRIPT = r"""
mode=$1; d=$2; shift 2
printf 'H\t%s\n' "$(hostname -s 2>/dev/null || hostname)"
intree=0; cd "$d" 2>/dev/null && intree=1
{
  for n in "$@"; do printf '%s\n' "$n"; done
  if [ "$mode" = all ] && [ "$intree" = 1 ]; then
    for x in */.git; do [ -e "$x" ] && printf '%s\n' "${x%/.git}"; done
  fi
} | sort -u | while IFS= read -r r; do
  [ -n "$r" ] || continue
  if [ "$intree" = 0 ] || [ ! -e "$r" ]; then printf 'R\t%s\tABSENT\n' "$r"; continue; fi
  if [ ! -e "$r/.git" ]; then printf 'R\t%s\tNOT_A_REPO\n' "$r"; continue; fi
  if ! s=$(git -C "$r" status --porcelain 2>/dev/null); then st=BROKEN
  elif [ -n "$s" ]; then st=DIRTY
  else st=CLEAN; fi
  printf 'R\t%s\t%s\n' "$r" "$st"
  c=$(git -C "$r" symbolic-ref --short HEAD 2>/dev/null) && printf 'C\t%s\t%s\n' "$r" "$c"
  git -C "$r" for-each-ref --format='%(refname) %(objectname)' refs/heads/ 2>/dev/null |
    while read -r n s; do printf 'B\t%s\t%s\t%s\n' "$r" "${n#refs/heads/}" "$s"; done
done
echo END
"""


class Probe:
    def __init__(self, text):
        self.host = ""
        self.state, self.current, self.heads = {}, {}, {}
        complete = False
        for line in text.splitlines():
            f = line.split("\t")
            if f[0] == "H" and len(f) == 2:
                self.host = f[1]
            elif f[0] == "R" and len(f) == 3:
                self.state[f[1]] = f[2]
                self.heads.setdefault(f[1], {})
            elif f[0] == "C" and len(f) == 3:
                self.current[f[1]] = f[2]
            elif f[0] == "B" and len(f) == 4:
                self.heads.setdefault(f[1], {})[f[2]] = f[3]
            elif f[0] == "END":
                complete = True
        self.complete = complete


class Peer:
    def __init__(self, addr, sock):
        self.addr, self.sock, self.connected = addr, sock, False
        ctl = ["-o", f"ControlPath={sock}", "-o", "ControlMaster=no"]
        self.ssh = ["ssh", *ctl, *SSH_OPTS, self.addr]
        self.env = dict(os.environ)
        self.env["GIT_SSH_COMMAND"] = " ".join(
            shlex.quote(x) for x in ["ssh", *ctl, *SSH_OPTS]
        )
        self.env["GIT_TERMINAL_PROMPT"] = "0"

    def connect(self):
        # ★ ONE CONNECTION PER PEER PER RUN. The master is the only handshake; every
        # later ssh and every git push/fetch rides its socket, which lives in a
        # private temp dir removed on exit.
        host = self.addr.split("@", 1)[-1]
        r = run(
            [
                "ssh",
                "-M",
                "-N",
                "-f",
                "-o",
                "ControlPersist=yes",
                "-o",
                f"ControlPath={self.sock}",
                *SSH_OPTS,
                self.addr,
            ],
            PROBE_TIMEOUT,
        )
        if r.timed_out:
            die(f"""ssh to {self.addr} neither answered nor failed within {PROBE_TIMEOUT}s — the connection was ACCEPTED
       and then went silent. A name that resolves to a CDN/proxy edge instead of to the host does
       exactly this, and ConnectTimeout cannot catch it because the TCP connect SUCCEEDS. Check what
       the name points at:  getent hosts {host}
       Raise the bound with PEER_SYNC_PROBE_TIMEOUT if the link is merely slow. Nothing was changed.""")
        # ssh's own stderr is CARRIED INTO the message — "unreachable" alone is true
        # and useless, and hides the difference between a closed laptop, a missing
        # known_hosts entry and a refused key.
        if r.rc != 0:
            die(
                f"cannot ssh to {self.addr} — {r.err.strip() or 'no output from ssh'}. Nothing was changed."
            )
        self.connected = True

    def close(self):
        if self.connected:
            run(["ssh", "-o", f"ControlPath={self.sock}", "-O", "exit", self.addr], 5)

    def sh(self, script, args, timeout, label=None):
        # `sh -s` with the script on stdin: the peer's login shell (zsh, fish, ...)
        # only parses `sh -s -- 'arg' ...`, never the script itself.
        cmd = "sh -s -- " + " ".join(shlex.quote(a) for a in args)
        return run([*self.ssh, cmd], timeout, label=label, stdin=script)

    def url(self, rdir, r):
        return f"{self.addr}:{rdir}/{r}"

    def agent_check(self):
        script = (
            'printf "%s\\n" "${SSH_AUTH_SOCK:-}"\n'
            '[ -n "${SSH_AUTH_SOCK:-}" ] || exit 0\n'
            "command -v ssh-add >/dev/null 2>&1 || exit 0\n"
            "ssh-add -l >/dev/null 2>&1\n"
            'echo "rc=$?"\n'
        )
        r = self.sh(script, [], AGENT_TIMEOUT + 10)
        if r.timed_out:
            sockp = (r.out.splitlines() or ["?"])[0] or "?"
            die(f"""the ssh agent on {self.addr} hangs: `ssh-add -l` there gave no answer (agent socket {sockp}).
       Every git fetch the peer makes over ssh would hang on it at agent lookup.
       On {self.addr}: systemctl --user restart ssh-agent-mux (or whatever serves that socket).
       Nothing was changed.""")

    def probe(self, rdir, names, mode):
        r = self.sh(
            PROBE_SCRIPT, [mode, rdir, *names], OP_TIMEOUT, label=f"probing {self.addr}"
        )
        if r.timed_out:
            die(
                f"the batched probe of {self.addr} did not finish within {OP_TIMEOUT}s "
                "(PEER_SYNC_OP_TIMEOUT). Nothing was changed."
            )
        p = Probe(r.out)
        if r.rc != 0 or not p.complete:
            die(
                f"the batched probe of {self.addr} failed or was truncated — {r.last_err()}. Nothing was changed."
            )
        return p


def local_agent_check():
    # ★ PRE-FLIGHT THE LOCAL AGENT BEFORE ANY NETWORK. Measured 2026-11-23: a wedged
    # ssh-agent-mux hung every ssh at agent lookup, and all the tool could say was a
    # generic probe timeout. `ssh-add -l` asks the same socket ssh would, under a
    # short bound, and names the socket. "No identities" (rc 1) is a live agent.
    sockp = os.environ.get("SSH_AUTH_SOCK", "")
    if not sockp:
        return
    r = run(["ssh-add", "-l"], AGENT_TIMEOUT)
    if r.timed_out:
        die(f"""agent socket {sockp} hangs: `ssh-add -l` gave no answer within {AGENT_TIMEOUT}s, and every ssh
       this run makes would hang on it at agent lookup. Restart the agent:
         systemctl --user restart ssh-agent-mux
       (or whatever serves that socket; PEER_SYNC_AGENT_TIMEOUT raises the bound). Nothing was changed.""")
    if r.rc == 2:
        emit(
            f"    note: no agent answers at {sockp} ({r.last_err()}); ssh will use key files only"
        )


def local_repos(root):
    out = []
    for x in sorted(os.listdir(root)):
        if not x.startswith(".") and os.path.exists(os.path.join(root, x, ".git")):
            out.append(x)
    return out


def in_transit(d):
    """The skip predicate for a repo the peer does not have.

    In transit ⇔ some local branch holds a commit that no CONFIGURED remote's
    tracking refs contain (as of this host's last fetch). Such a commit exists only
    here, so it must move. A dir whose every branch is already on origin (or any
    configured remote) carries nothing the peer cannot fetch itself; a dir with no
    remote at all is always in transit. refs/remotes/<host>/ fallback namespaces
    have no configured remote and so never count as "held elsewhere".
    """
    remotes = git(d, "remote").out.split()
    r = git(
        d,
        "rev-list",
        "-n1",
        "--branches",
        "--not",
        *[f"--remotes={x}" for x in remotes],
    )
    return r.rc != 0 or bool(r.out.strip())


class Outcome:
    def __init__(self, repo, bucket, action, detail=""):
        self.repo, self.bucket, self.action, self.detail = repo, bucket, action, detail
        self.dirty = False
        self.unpushed = 0
        self.elapsed = 0.0

    def label(self):
        return f"{self.repo}({self.detail})" if self.detail else self.repo


class Run:
    def __init__(self, o, peer, peer_name, probe):
        self.o, self.p, self.peer_name, self.probe = o, peer, peer_name, probe
        self.local = set()

    # ---------------------------------------------------------------- push (--to)
    def job_sync(self, r):
        o, d = self.o, os.path.join(self.o.root, r)
        st = self.probe.state.get(r, "ABSENT")
        if r not in self.local:
            # Sync never clones peer-only repos here; that is --from --clone-new.
            return Outcome(r, "peer-only", f"on {self.peer_name} only")
        heads = local_heads(d)
        if st == "ABSENT":
            if not in_transit(d):
                return Outcome(
                    r, "skipped", f"absent on {self.peer_name}", "not-in-transit"
                )
            if o.check:
                return Outcome(
                    r,
                    "here-only",
                    f"absent on {self.peer_name}",
                    f"would create, {len(heads)} branch(es)",
                )
            return self.create(r, d, heads)
        if st != "CLEAN":
            # DIRTY, NOT_A_REPO, BROKEN. ★ NOTHING IS WRITTEN to a checkout we cannot
            # reason about, nor to one holding uncommitted work: not its branches,
            # not the fallback namespace.
            return Outcome(
                r,
                "needs-review",
                f"{self.peer_name} is {st.lower().replace('_', '-')}",
                st.lower().replace("_", "-"),
            )
        theirs = self.probe.heads.get(r, {})
        moving = sorted(b for b, s in heads.items() if theirs.get(b) != s)
        if not moving:
            # "Nothing new versus the peer": every local branch is already there at
            # the same sha, read from the batched probe. No push, no extra ssh.
            return Outcome(r, "ok", "up to date")
        if o.check:
            diverged = [
                b
                for b in moving
                if b in theirs and not self.ancestor(d, theirs[b], heads[b])
            ]
            if diverged:
                return Outcome(
                    r,
                    "needs-review",
                    f"would push {', '.join(moving)}",
                    f"would-not-ff:{','.join(diverged)}",
                )
            return Outcome(r, "ok", f"would push {', '.join(moving)}")
        return self.push_existing(r, d, heads, moving)

    @staticmethod
    def ancestor(d, a, b):
        return git(d, "merge-base", "--is-ancestor", a, b).rc == 0

    def refspecs(self, heads, force):
        # ★ EXPLICIT PER-BRANCH REFSPECS. Two PATTERN refspecs over the same source
        # (`refs/heads/*:refs/heads/*` plus `+refs/heads/*:refs/remotes/<self>/*`)
        # match each local ref ONCE — measured 2026-11-23, git silently dropped the
        # fallback half. Named refs carry both destinations in one push.
        plus = "+" if force else ""
        out = []
        for b in sorted(heads):
            out += [
                f"{plus}refs/heads/{b}:refs/heads/{b}",
                f"+refs/heads/{b}:refs/remotes/{self.o.self}/{b}",
            ]
        return out

    def push(self, r, d, refspecs, receive_pack=None):
        cmd = ["git", "-C", d, "push", "--porcelain"]
        if receive_pack:
            cmd.append(f"--receive-pack={receive_pack}")
        cmd += [self.p.url(self.o.dir, r), *refspecs]
        return run(cmd, OP_TIMEOUT, label=f"pushing {r}", env=self.p.env)

    def read_heads(self, r, fetch_origin):
        # ★ REFRESH THE PEER'S VIEW OF ORIGIN. Fast-forwarding its branch without this
        # leaves `refs/remotes/origin/*` at whatever the peer last fetched, so the first
        # thing a handoff session sees is a LIE: `git status` reported `ahead 3` on a
        # branch that was exactly in sync. Measured 2026-08-28: 26 of 57 peer repos
        # carrying an origin ref were stale straight after a clean sync. Failure is
        # non-fatal — the peer may have no route to origin, and the branches are
        # already correct regardless. Bounded on the peer by `timeout` where it exists
        # (macOS lacks it) and here by the call's own bound. Folded into the re-read
        # of the heads so it costs no extra round trip.
        script = r"""
t=$1; fo=$2; to=$3
if [ "$fo" = 1 ]; then
  if command -v timeout >/dev/null 2>&1; then
    GIT_TERMINAL_PROMPT=0 timeout "$to" git -C "$t" fetch --quiet --prune origin >/dev/null 2>&1
  else
    GIT_TERMINAL_PROMPT=0 git -C "$t" fetch --quiet --prune origin >/dev/null 2>&1
  fi
  echo "FETCH $?"
fi
git -C "$t" for-each-ref --format='%(refname) %(objectname)' refs/heads/ || exit 1
echo END
"""
        res = self.p.sh(
            script,
            [f"{self.o.dir}/{r}", "1" if fetch_origin else "0", str(OP_TIMEOUT)],
            OP_TIMEOUT + 30,
            label=f"refreshing {r} on {self.peer_name}",
        )
        fetch_rc = None
        for line in res.out.splitlines():
            if line.startswith("FETCH "):
                fetch_rc = line.split()[1]
        ok = res.rc == 0 and res.out.rstrip().endswith("END")
        return ok, parse_heads(res.out), fetch_rc, res

    def push_existing(self, r, d, heads, moving):
        # ★ FAST-FORWARD THE PEER'S REAL BRANCHES. A handoff session runs `git status` and
        # `git log`; it does not begin by checking which iteration of main it is on, or
        # whether some side namespace holds a better one. So the work has to land ON the
        # branch it expects, at the sha it expects.
        # Mirroring into `refs/remotes/<self>/` failed that: with no configured remote,
        # `blade/main` did not even resolve — measured, `warning: refname 'blade/main' is
        # ambiguous` — and neither `git remote -v` nor `git branch` showed anything.
        # ★★ NO `+` ON refs/heads. Git fast-forwards what it can and refuses divergence PER
        # REF, so what lands is exactly what a handoff can trust, and the check is enforced
        # by the thing that owns the invariant. `updateInstead` carries a fast-forward into
        # a CLEAN worktree and refuses a dirty one; it is set for this receive-pack only
        # (`git -c`), so the peer's config is not rewritten.
        # The fallback refspec rides the same push: a branch that could NOT fast-forward
        # still arrives under refs/remotes/<self>/, so diverged work is never stranded on
        # one host — it is simply not pretended to be the peer's branch.
        res = self.push(
            r,
            d,
            self.refspecs(heads, force=False),
            receive_pack="git -c receive.denyCurrentBranch=updateInstead receive-pack",
        )
        action = f"push {', '.join(moving)}"
        if res.timed_out:
            return Outcome(r, "failed", action, f"push timed out after {OP_TIMEOUT}s")
        rejected = [x for x in res.out.splitlines() if x.startswith("!")]
        if res.rc != 0 and not rejected:
            return Outcome(r, "failed", action, f"push: {res.last_err()}")
        ok, after, fetch_rc, rr = self.read_heads(r, fetch_origin=True)
        if not ok:
            why = (
                f"timed out after {OP_TIMEOUT + 30}s" if rr.timed_out else rr.last_err()
            )
            return Outcome(r, "failed", action, f"re-read on peer: {why}")
        # ★ THE BUCKET IS DECIDED BY RE-READING THE PEER'S REFS, never by the push's exit
        # status: an update that silently did nothing and one that was refused look
        # identical from here, and both must land in review rather than in ok.
        stuck = sorted(b for b, s in heads.items() if after.get(b) != s)
        if stuck:
            return Outcome(r, "needs-review", action, f"no-ff:{','.join(stuck)}")
        note = " (peer origin fetch timed out)" if fetch_rc == "124" else ""
        return Outcome(r, "ok", action + note)

    def create(self, r, d, heads):
        # ★ INIT ON THE PEER AND PUSH, rather than having the peer clone from us.
        # A reverse clone needs the PEER to resolve and reach US, which silently
        # requires reverse connectivity and cannot work when the caller gave an
        # IP or an ssh alias. Push-only means exactly one direction has to work:
        # the one the reachability check already proved.
        # `receive.denyCurrentBranch=updateInstead` populates the fresh working
        # tree, safe precisely because the repo was just created.
        # ★ PROBE THE PATH ITSELF. The batched probe tested this exact path, not a
        # `*/.git` glob (defeated by a different --dir, a bare repo, or a linked
        # worktree whose `.git` is a FILE), and the init re-tests it: `git init` on an
        # existing repo is a NO-OP rather than a failure, so a wrong "absent" used to
        # reach a force-push into real branches, overwriting the peer's branches.
        hb = git(d, "symbolic-ref", "--short", "HEAD").out.strip() or "main"
        ou = git(d, "remote", "get-url", "origin").out.strip()
        t = f"{self.o.dir}/{r}"
        init = r"""
t=$1; d=$2; hb=$3; ou=$4
[ ! -e "$t" ] || { echo EXISTS; exit 3; }
mkdir -p "$d" && git init -q -b "$hb" "$t" && git -C "$t" config receive.denyCurrentBranch updateInstead || exit 1
[ -z "$ou" ] || git -C "$t" remote add origin "$ou"
"""
        action = f"create on {self.peer_name}, push {len(heads)} branch(es)"
        res = self.p.sh(
            init, [t, self.o.dir, hb, ou], OP_TIMEOUT, label=f"creating {r}"
        )
        if res.timed_out:
            return Outcome(r, "failed", action, f"create timed out after {OP_TIMEOUT}s")
        if "EXISTS" in res.out:
            return Outcome(r, "needs-review", action, "appeared-on-peer")
        if res.rc != 0:
            return Outcome(r, "failed", action, f"create: {res.last_err()}")
        # Nothing there to lose, so force is safe.
        res = self.push(r, d, self.refspecs(heads, force=True))
        if res.timed_out:
            return Outcome(r, "failed", action, f"push timed out after {OP_TIMEOUT}s")
        if res.rc != 0:
            return Outcome(r, "failed", action, f"push: {res.last_err()}")
        # ★ SET THE UPSTREAM, which `git init` + push does not and `git clone` does.
        # Adding the remote is not enough: with no branch.<name>.remote/.merge the
        # first thing a handoff session does — `git pull` — dies with 'There is no
        # tracking information for the current branch', on a repo whose `git remote -v`
        # looks perfectly correct. Written directly rather than via --set-upstream-to,
        # which needs refs/remotes/origin/* to already exist and so would require a
        # fetch the peer may have no route (or no credentials) to make.
        fin = r"""
t=$1; hb=$2; ou=$3
git -C "$t" symbolic-ref HEAD "refs/heads/$hb"
[ -z "$ou" ] || { git -C "$t" config "branch.$hb.remote" origin
                  git -C "$t" config "branch.$hb.merge" "refs/heads/$hb"; }
git -C "$t" checkout -q -- . 2>/dev/null || true
"""
        res = self.p.sh(fin, [t, hb, ou], OP_TIMEOUT, label=f"finishing {r}")
        if res.rc != 0:
            return Outcome(r, "failed", action, f"finish: {res.last_err()}")
        ok, after, _, rr = self.read_heads(r, fetch_origin=False)
        stuck = sorted(b for b, s in heads.items() if after.get(b) != s)
        if not ok or stuck:
            return Outcome(
                r,
                "failed",
                action,
                f"created but not verified: {','.join(stuck) or rr.last_err()}",
            )
        return Outcome(r, "ok", action, "created-on-peer")

    # ---------------------------------------------------------------- pull (--from)
    def job_pull(self, r):
        o, p, d = self.o, self.p, os.path.join(self.o.root, r)
        st = self.probe.state.get(r, "ABSENT")
        there = st in ("CLEAN", "DIRTY", "BROKEN")
        if r not in self.local:
            # ★ REPORT, DO NOT CLONE, UNLESS ASKED. The hosts legitimately carry
            # different repo sets — measured 2026-08-28, one held 38 and the other 64,
            # the extra 26 being unrelated projects rather than work in flight. A pull
            # that cloned every peer-only repo would dump all of them here, which is
            # not "syncing work" but "making two machines identical", a different and
            # unasked-for thing. Naming them is the useful part; --clone-new opts in.
            if o.clone_new and not o.check:
                # Cloning FROM the peer needs only the direction the reachability
                # check already proved.
                res = run(
                    ["git", "clone", "-q", p.url(o.dir, r), d],
                    OP_TIMEOUT,
                    label=f"cloning {r}",
                    env=p.env,
                )
                if res.rc == 0:
                    return Outcome(
                        r, "ok", f"clone from {self.peer_name}", "cloned-from-peer"
                    )
                why = (
                    f"clone timed out after {OP_TIMEOUT}s"
                    if res.timed_out
                    else f"clone: {res.last_err()}"
                )
                return Outcome(r, "failed", f"clone from {self.peer_name}", why)
            return Outcome(r, "peer-only", f"on {self.peer_name} only")
        if not there:
            return Outcome(r, "here-only", f"{self.peer_name} has never checked it out")
        theirs = self.probe.heads.get(r, {})
        mine = local_heads(d)
        moving = sorted(b for b, s in theirs.items() if mine.get(b) != s)
        if not moving:
            return Outcome(r, "ok", "up to date")
        action = f"fetch {', '.join(moving)}"
        if o.check:
            return Outcome(r, "ok", "would " + action)
        # Same reason as the push arm's peer refresh, mirrored: this side is the one
        # being updated, so this side's view of origin is the one that goes stale.
        run(
            ["git", "-C", d, "fetch", "--quiet", "--prune", "origin"],
            OP_TIMEOUT,
            label=f"fetching origin for {r}",
            env=p.env,
        )
        # One round trip for every branch, into the FALLBACK namespace. --prune so the
        # namespace mirrors the peer exactly and a branch deleted there cannot be read
        # back below as one that failed to arrive.
        res = run(
            [
                "git",
                "-C",
                d,
                "fetch",
                "-q",
                "--prune",
                p.url(o.dir, r),
                f"+refs/heads/*:refs/remotes/{self.peer_name}/*",
            ],
            OP_TIMEOUT,
            label=f"fetching {r}",
            env=p.env,
        )
        if res.rc != 0:
            why = (
                f"fetch timed out after {OP_TIMEOUT}s"
                if res.timed_out
                else f"fetch: {res.last_err()}"
            )
            return Outcome(r, "failed", action, why)
        # ★★★ FAST-FORWARD THIS HOST'S REAL BRANCHES. Landing the refs ONLY under
        # refs/remotes/<peer>/ is what made a --from run read as "nothing transferred"
        # while every commit had in fact arrived: measured 2026-08-30, three gen-* repos
        # held the peer's shas in the local object store with main still at the older
        # commit and no configured remote, so `<peer>/main` did not even resolve.
        # ★★ THE PUSH ARM GETS THIS FREE FROM `receive.denyCurrentBranch=updateInstead`
        # AND FETCH HAS NO EQUIVALENT. Measured 2026-08-30 on a fixture: a single
        # `fetch <url> refs/heads/*:refs/heads/*` dies `fatal: refusing to fetch into
        # branch ... checked out at ...` with exit 128 and ABORTS THE WHOLE FETCH — the
        # fast-forwardable siblings did not move either. So the update is done locally,
        # per branch, out of the namespace just fetched: no extra round trip, and the
        # ancestry test stays git's.
        cur = git(d, "symbolic-ref", "--short", "HEAD").out.strip()
        clean = git(d, "status", "--porcelain").out.strip() == ""
        stuck = []
        for pname, psha in sorted(
            local_heads(d, f"refs/remotes/{self.peer_name}/").items()
        ):
            lsha = mine.get(pname)
            if pname == cur:
                # The checked-out branch: `merge --ff-only` IS the local `updateInstead`. It
                # carries a fast-forward into a CLEAN worktree and refuses everything else,
                # so a dirty tree is never silently overwritten.
                if clean:
                    git(d, "merge", "--ff-only", "-q", psha)
            elif lsha is None:
                # New branch here. There is no ancestry question to answer.
                git(d, "update-ref", f"refs/heads/{pname}", psha)
            elif self.ancestor(d, lsha, psha):
                git(d, "update-ref", f"refs/heads/{pname}", psha, lsha)
            # ★ THE BUCKET IS DECIDED BY RE-READING THE REF, never by the exit status of the
            # arm above. An update that silently did nothing and one that was refused look
            # identical from here, and both must land in review rather than in ok.
            if (
                git(d, "rev-parse", "-q", "--verify", f"refs/heads/{pname}").out.strip()
                != psha
            ):
                stuck.append(pname)
        if stuck:
            return Outcome(r, "needs-review", action, f"no-ff:{','.join(stuck)}")
        return Outcome(r, "ok", action)

    def job(self, r):
        t0 = time.monotonic()
        d = os.path.join(self.o.root, r)
        try:
            oc = (self.job_sync if self.o.direction == "sync" else self.job_pull)(r)
        except Exception as e:  # noqa: BLE001 — a bug must land in a bucket, never drop the repo
            oc = Outcome(r, "failed", "internal error", repr(e))
        if r in self.local:
            oc.dirty = git(d, "status", "--porcelain").out.strip() != ""
            if git(d, "rev-parse", "@{u}").rc == 0:
                n = git(d, "rev-list", "--count", "@{u}..HEAD").out.strip()
                oc.unpushed = int(n) if n.isdigit() else 0
        oc.elapsed = time.monotonic() - t0
        return oc


def selected(o, r):
    if o.include and not any(fnmatch.fnmatchcase(r, g) for g in o.include):
        return False
    return not any(fnmatch.fnmatchcase(r, g) for g in o.exclude)


def sync_peer(o, dest, sock, opened):
    # A destination already carrying user@ is passed through untouched, so ssh
    # aliases and `user@10.0.0.4` both work without special-casing.
    addr = dest if "@" in dest else f"{o.user or o.local_user}@{dest}"
    emit("")
    # Named explicitly, so being unreachable is an error rather than a fact to
    # note: every peer here was asked for by the caller.
    p = Peer(addr, sock)
    opened.append(p)
    p.connect()
    p.agent_check()

    # ★ THE UNIVERSE IS BOTH SIDES, NOT THE LOCAL TREE. Enumerating only local
    # repos meant a repo existing solely on the peer was never reached: it landed
    # in no bucket, and the bucket-sum guard below still passed — because it was
    # summing over the wrong universe. Measured 2026-08-28: a --pull run reported
    # `repos: 38, ok: 38, absent-on-peer: 0` while 25 peer-only repos went
    # unmentioned. The batched probe enumerates the peer's tree AND tests every
    # local name by path, in the same single call.
    all_local = local_repos(o.root)
    local = [r for r in all_local if selected(o, r)]
    probe = p.probe(o.dir, local, "all")
    # ★ THE PEER'S OWN NAME labels the ref namespace. Deriving it from DEST meant an
    # IP labelled its refs `10`; asking the host what it is called removes that.
    peer_name = "".join(
        c for c in probe.host.split(".")[0] if c.isalnum() or c in "._-"
    )
    if not peer_name:
        peer_name = dest.split("@", 1)[-1].split(".")[0]
    peer_repos = [
        r
        for r, s in probe.state.items()
        if r not in all_local and s not in ("ABSENT", "NOT_A_REPO")
    ]
    universe = sorted(set(local) | {r for r in peer_repos if selected(o, r)})
    excluded = (len(all_local) - len(local)) + sum(
        1 for r in peer_repos if not selected(o, r)
    )
    say(
        f"{o.self} -> {peer_name}   dest={addr}   mode={o.mode}   dir={o.dir}   jobs={o.jobs}"
    )
    if excluded:
        emit(f"    {excluded} repo(s) left out by --include/--exclude")

    R = Run(o, p, peer_name, probe)
    R.local = set(local)
    # ★ COUNT THE UNIVERSE BEFORE THE LOOP. The bucket arithmetic below sums against
    # `total`, which the loop increments — so a loop that TERMINATES EARLY sums perfectly
    # against its own truncated view and reports a clean run. Measured 2026-08-28: an `ssh`
    # inside the read loop consumed the loop's stdin, 64 repos became 5, and every bucket
    # still balanced. Only the ref verification caught it.
    universe_n = len(universe)
    buckets = {b: [] for b in BUCKETS}
    dirty, unpushed = [], []
    total = 0
    ex = ThreadPoolExecutor(max_workers=o.jobs)
    try:
        futs = [ex.submit(R.job, r) for r in universe]
        for f in as_completed(futs):
            oc = f.result()
            total += 1
            res = oc.bucket + (f": {oc.detail}" if oc.detail else "")
            emit(
                f"[{total}/{universe_n}] {oc.repo}: {oc.action} -> {res} ({oc.elapsed:.1f}s)"
            )
            buckets[oc.bucket].append(oc)
            if oc.dirty:
                dirty.append(oc.repo)
            if oc.unpushed:
                unpushed.append(f"{oc.repo}:{oc.unpushed}")
    finally:
        ex.shutdown(wait=False, cancel_futures=True)

    n = {b: len(v) for b, v in buckets.items()}

    def names(b):
        return " ".join(sorted(x.label() for x in buckets[b]))

    overall = 0
    say(
        f"repos: {total} (both sides)   ok: {n['ok']}   here-only: {n['here-only']}   peer-only: {n['peer-only']}"
        f"   skipped: {n['skipped']}   failed: {n['failed']}   needs-review: {n['needs-review']}"
    )
    if n["here-only"]:
        emit(
            f"    here only — {peer_name} has never checked these out; --to creates them there: {names('here-only')}"
        )
    if n["peer-only"]:
        emit(
            f"    on {peer_name} only — not present here; --from --clone-new would clone them: {names('peer-only')}"
        )
    if n["skipped"]:
        emit(
            f"    skipped, not in transit — absent on {peer_name}, every branch already on a configured remote:"
            f" {names('skipped')}"
        )
    if n["failed"]:
        emit(f"    FAILED: {names('failed')}", err=True)
        overall = 1
    if n["needs-review"]:
        emit(
            f"    NEEDS MANUAL REVIEW — the peer already holds these and nothing was written to its branches:"
            f" {names('needs-review')}",
            err=True,
        )
        emit(
            "      no-ff = the peer's branch is not an ancestor of ours, so it was NOT moved; the commits\n"
            "      are on the peer under refs/remotes/<self>/ and need a human merge or rebase.\n"
            "      diverged = the peer has commits this host does not; dirty = uncommitted work there,\n"
            "      so NOTHING was written to it;",
            err=True,
        )
        emit(
            "      not-a-repo / broken = the path exists but is not a checkout we can reason about.",
            err=True,
        )
        overall = 1
    if dirty:
        emit(
            f"    uncommitted — NOT transferred by this tool: {' '.join(sorted(dirty))}"
        )
    if unpushed:
        emit(
            f"    unpushed to origin (fine, the peer has them): {' '.join(sorted(unpushed))}"
        )

    if total != universe_n:
        die(
            f"the repo loop processed {total} of {universe_n} repos for {peer_name} — it terminated early. "
            "Do not trust this run."
        )
    if sum(n.values()) != total:
        die(
            f"bucket arithmetic does not sum for {peer_name}: {'+'.join(str(n[b]) for b in BUCKETS)} != {total}. "
            "A repo was dropped silently; do not trust this run."
        )

    if o.check:
        return overall

    # Verify what was just claimed, rather than trusting the transfer's exit code: one
    # batched re-read of the peer for every repo in the ok bucket.
    if o.direction == "sync":
        say(f"verifying every local branch is on {peer_name} at the same sha")
    else:
        say(
            f"verifying every branch fetched from {peer_name} is present here at the same sha"
        )
    ok_repos = sorted(x.repo for x in buckets["ok"])
    post = p.probe(o.dir, ok_repos, "listed")
    bad = checked = 0
    for r in ok_repos:
        mine = local_heads(os.path.join(o.root, r))
        theirs = post.heads.get(r, {})
        # ★ VERIFY AGAINST THE REAL BRANCHES on the receiving side — that is where a
        # handoff will look. Checking the namespace only was how a --from could report
        # VERIFIED while every local branch still pointed at the older commit.
        want, have = (mine, theirs) if o.direction == "sync" else (theirs, mine)
        for b, s in sorted(want.items()):
            checked += 1
            if have.get(b) != s:
                emit(f"    MISMATCH {r}: {b}@{s[:8]} did not arrive", err=True)
                bad += 1
    if bad:
        emit(
            f"    ★ {bad} of {checked} ref(s) did not arrive. The sync with {peer_name} is INCOMPLETE — "
            "do not hand off on it.",
            err=True,
        )
        overall = 1
    else:
        say(f"VERIFIED: {checked} ref(s) present at matching shas")
    return overall


USAGE = """peer-sync — make a peer's checkouts match this host's, verifiably.

  peer-sync --to DEST      send this host's branches to DEST
  peer-sync --from DEST    bring DEST's branches here
  peer-sync --check --to DEST    report what would move; change nothing

DEST is anything ssh accepts, and is the only thing you have to say:
  cortex          cortex.ts.example.net          10.0.0.4
  user@10.0.0.4   my-ssh-alias

Branches FAST-FORWARD. A branch that cannot fast-forward is never moved; it is
carried into refs/remotes/<peer>/ and the repo is reported as needing review.
A peer checkout with uncommitted work is never written to.

Options:
  --to DEST          REQUIRED (or --from). Repeatable. Push direction.
  --from DEST        REQUIRED (or --to). Repeatable. Pull direction. Fast-forwards THIS
                     host's branches; a branch that cannot is left alone and reported.
  --check            report only; write nothing
  --clone-new        with --from, also clone repos DEST has and this host does not.
                     Off by default: the hosts legitimately differ, and cloning
                     every peer-only repo makes them identical rather than
                     transferring work.
  --dir PATH         repo tree, relative to $HOME on BOTH hosts
                     (default: Documents/repos/sini)
  --root PATH        absolute local repo tree; overrides --dir locally
  --user NAME        ssh user, when DEST carries no user@ (default: this host's)
  --include GLOB     only repos whose dir name matches; repeatable
  --exclude GLOB     leave out repos whose dir name matches; repeatable
  -j N               repos in flight at once (default 4, max 32)
  -h, --help         this

Skipped by default (bucket `skipped`): with --to, a dir the peer does not have
whose every branch is already contained in a configured remote's tracking refs
(e.g. origin/*). It holds no commit that exists only here, so it is not work in
transit; the peer can clone it from origin. A dir on both sides whose branches
already match the peer's (read from the one batched probe) is `ok`, untouched.

Environment (seconds): PEER_SYNC_PROBE_TIMEOUT (connect, 20), PEER_SYNC_OP_TIMEOUT
(each push/fetch/remote call, 300), PEER_SYNC_AGENT_TIMEOUT (ssh-add -l, 5),
PEER_SYNC_HEARTBEAT (progress during a long push, 15).
"""


class Opts:
    pass


def parse(argv):
    o = Opts()
    o.direction = ""
    o.check = o.clone_new = False
    o.dir, o.root, o.user = DEFAULT_DIR, "", ""
    o.peers, o.include, o.exclude = [], [], []
    o.jobs = 4

    def need(i):
        if i + 1 >= len(argv):
            print(f"{argv[i]} needs a value", file=sys.stderr)
            print(USAGE, file=sys.stderr)
            sys.exit(2)
        return argv[i + 1]

    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ("--to", "--from"):
            want = "sync" if a == "--to" else "pull"
            if o.direction and o.direction != want:
                print(
                    "REFUSED: --to and --from are opposite directions; pick one",
                    file=sys.stderr,
                )
                sys.exit(1)
            o.direction = want
            o.peers.append(need(i))
            i += 2
        elif a == "--check":
            o.check = True
            i += 1
        elif a == "--clone-new":
            o.clone_new = True
            i += 1
        elif a in ("--dir", "--root", "--user", "--include", "--exclude", "-j"):
            v = need(i)
            if a == "--dir":
                o.dir = v
            elif a == "--root":
                o.root = v
            elif a == "--user":
                o.user = v
            elif a == "--include":
                o.include.append(v)
            elif a == "--exclude":
                o.exclude.append(v)
            else:
                if not v.isdigit() or int(v) < 1:
                    print(f"-j needs a positive integer, got {v!r}", file=sys.stderr)
                    sys.exit(2)
                o.jobs = min(int(v), 32)
            i += 2
        elif a in ("-h", "--help"):
            print(USAGE)
            sys.exit(0)
        else:
            print(f"unknown argument: {a}", file=sys.stderr)
            print(USAGE, file=sys.stderr)
            sys.exit(2)
    if not o.direction:
        print(
            "REFUSED: no direction given. --to DEST sends this host's branches there; --from DEST brings\n"
            "         DEST's branches here. This tool will not guess which way work should move.",
            file=sys.stderr,
        )
        print(USAGE, file=sys.stderr)
        sys.exit(2)
    o.mode = "check" if o.check else o.direction
    # `hostname` returns e.g. `laptop.local` on darwin and a bare name on NixOS.
    o.self = socket.gethostname().split(".")[0]
    o.local_user = getpass.getuser()
    o.root = o.root or os.path.join(os.path.expanduser("~"), o.dir)
    return o


def main(argv):
    o = parse(argv)
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(143))
    if not os.path.isdir(o.root):
        print(
            f"REFUSED: local repo tree not found: {o.root} (set --root or --dir)",
            file=sys.stderr,
        )
        return 1
    tmp = tempfile.mkdtemp(prefix="peer-sync-")
    opened = []
    overall = 0
    try:
        local_agent_check()
        for i, dest in enumerate(o.peers):
            overall |= sync_peer(o, dest, os.path.join(tmp, f"c{i}"), opened)
    except Refused as e:
        emit(f"REFUSED: {e}", err=True)
        return 1
    except KeyboardInterrupt:
        emit(
            "REFUSED: interrupted — this run is incomplete; do not hand off on it.",
            err=True,
        )
        return 130
    finally:
        kill_live()
        for p in opened:
            p.close()
        shutil.rmtree(tmp, ignore_errors=True)
    emit("")
    if o.check:
        say("CHECK ONLY — nothing was changed. Re-run without --check to act.")
    elif overall == 0:
        say("HANDOFF READY: every peer verified.")
    else:
        emit(
            "REFUSED: one or more peers are NOT ready — see the lines above. Do not hand off on this run.",
            err=True,
        )
        return 1
    return overall


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
