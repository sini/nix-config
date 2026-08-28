# Dispatch template — for the ORCHESTRATOR, not for an agent

The four agents (composed from the fragments here — see `README.md`) already
carry the standing half of every dispatch: instrument facts, measurement law,
reporting rules, the hand-off table, and the `NEEDS_CONTEXT` / `BLOCKED` /
`STOP-AND-PROMOTE` protocol. That is ~78 lines per agent that a prompt used to
restate and no longer should.

**So a dispatch carries the task-specific half only.** Restating the standing
facts is not harmless: it doubles the prompt, and when the two copies drift the
agent has two sources of truth for the same rule.

This file is not installed as an agent — `gen-agents.nix` registers the four by
name, so an unreferenced `.md` here is repo-only by construction.

---

## The form

```
You are <bead>-<role>.                      # NAME EVERY AGENT; the roster shows it
Agent: gen-scout | gen-spec | gen-gate | gen-build

CARRIER:   den-hoag-<id>                    # the graph anchor; findings return here
TIER:      M | D | R                        # classify at filing (M drops ceremony, never delegation)

PREMISE — tag every line. Conclusions, never the reasoning that got there:
  [MEASURED <sha>]  <claim>  --  <the command, so the agent can re-run it>
  [RELAYED <source>] <claim>  --  who said it; you have not checked it
  [ASSUMED]          <claim>  --  you believe it and have no evidence

SCOPE:
  IN:      <exactly what to touch>
  OUT:     <what is deliberately excluded, and why it is not an oversight>
  CLASS:   instance | discharge the class      # say which; authors default to instance

DELIVERABLE:
  reports/den-hoag-<id>-<agent>-v0.md          # v bumps per round
  <or: the named files to edit, at their paths>

WORKTREE:  <path> at <explicit HEAD sha>       # one writer per worktree
           <or: read-only, no checkout needed>

EXIT:      <what done is>                      # default A9: one construction-clean contact
```

## The four things that are not optional

**1. The premise is a conclusion, not an argument — but tag what you actually
know.** Do not include the reasoning: an agent that inherits it cannot
independently reach a different answer, which is the whole point of a fresh
context. That much holds and was re-confirmed against the corpus.

What does not hold is presenting every premise as established. **Measured across
four independent samples, dispatches carried a false load-bearing claim in 4/8,
4/8, 5/8 and 8/8 of runs** — stale coordinates, wrong counts, a wrong cause, two
instructions in mutual conflict. An untagged brief invites an agent to build on
your guesses at the same weight as your measurements, and the old form had **no
slot at all for a premise with no command behind it**, so those got written as
though they had one.

`[MEASURED]` carries the command, not its output, so the agent can re-run it —
that is what makes a brief auditable rather than merely confident. Emphasis is
not evidence: one brief's ★-marked "a bisect just established the cause" was
precisely the false part.

**2. If the task has an oracle, its RED and GREEN are EVALUATED BEFORE the cell
is written, and that requirement goes in THIS dispatch.** Not derived after the
fact from whatever the code returns. Adopted after a REJECT; measured to work —
three false values became zero in the run that followed.

**3. Say `discharge the class` when you mean it.** The default author behaviour
is to fix the instance you named. If the class is the target, the dispatch must
say so, and say how to enumerate its members.

**4. Ask THEORY, MECHANISM and ARGUMENT apart.** A single "is this right?" gets
one blended answer. Three questions get three findings, and they fail
independently.

## Tells that a dispatch is wrong before it is sent

- It restates instrument facts the agent already carries → cut them. When they
  were restated, they were restated **wrong**: the role files scope the stderr
  rule to measurements ("do not silence stderr on a measurement"), dispatches
  copied it unscoped, and compliant navigation commands then read as violations.
  A rule worth repeating is worth linking to instead.
- It contains the word "carefully" or "make sure" → that is not a specification.
- It asks for a fix and a report in the same breath → an audit that edits cannot
  report what it found. Split it, or use gen-scout then gen-build.
- Its premise cites a disposition block's own "VERIFIED" → that is a snapshot;
  the agent's first job is re-derivation at HEAD, so give it the sha.
- You cannot state EXIT → you do not yet know what you are asking for.

## Reachability

Pointed to from `den-ag-design/STATUS/RESUME-PROMPT-ARCH.md`, immediately before
its graph-instructions section — the orchestrator's standing entry point, so
this is read at boot rather than discovered. That pointer also carries the
measured brief-error rate, which is the reason the premise field is tagged.
