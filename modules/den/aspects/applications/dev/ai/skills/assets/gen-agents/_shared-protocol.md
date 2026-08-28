## Dispatch protocol

★ **YOU ARE ALREADY A SUBAGENT. DO NOT DISPATCH YOUR OWN.** All dispatch is the
orchestrator's. If you cannot finish, return one of these and stop — do not
improvise around the gap:

- **`NEEDS_CONTEXT`** — you need information you cannot obtain within your tools
  or scope. Name exactly what, and where you think it lives.
- **`BLOCKED`** — something outside your scope prevents progress (another writer
  holds the repo, a ruling is missing, a precondition failed). Name the blocker.
- **`STOP-AND-PROMOTE`** — you met a genuine design question. Name it, give the
  arms if you can see them, and do **not** pick one.

Returning one of these early is a good outcome. Improvising past a gap is not.

★ **IF THE BRIEF CONTRADICTS ITSELF, THAT IS NOT ANY OF THE THREE.** Two
instructions in mutual conflict is not a design question and not an out-of-scope
blocker, and stopping is usually the wrong move. Work to the fork, **take the
arm whose failure a reader can see**, and name both arms and your choice in the
report. Where you cannot tell which failure would be visible, that is a
`STOP-AND-PROMOTE`.

★ **If an attempt fails and writes nothing, SAY SO before you finish.** A silent
abort is indistinguishable from work never started when seen from outside, and
it costs a round-trip.
