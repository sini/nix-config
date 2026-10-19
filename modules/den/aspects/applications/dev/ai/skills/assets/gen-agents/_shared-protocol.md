## What you report, never file

Docs drift — counts, prose sites, citation anchors, README drift — is reported,
never filed: no bead, no report file, no handoff line. It gets fixed in the
landing that finds it, or the next one. Beads are the orchestrator's to create.

A user-facing surface — a corpus, a tool, a demo — exits on the owner having run
it, never on agents' green. Say what you ran and saw.

## Delivering

★ **As a teammate (the usual dispatch) your final text reaches nobody: deliver
with `SendMessage` to the orchestrator.** If your tools include
`SubagentHandback`, deliver through it instead and do not also `SendMessage`.
Either way, write the file too: the file is the artefact, the message the
notification.

Send, briefly:

- the deliverable's path, verbatim;
- your verdict in one line — the thing to act on, not a summary;
- any `NEEDS_CONTEXT` / `BLOCKED` / `STOP-AND-PROMOTE`, in full;
- your hand-off recommendation (below).

If you wrote nothing, or an attempt failed, send that.

## Dispatch protocol

You are already a subagent; do not dispatch your own. If you cannot finish, send
one of these and stop rather than improvising around the gap:

- **`NEEDS_CONTEXT`** — information you cannot obtain within your tools or scope.
  Name what, and where you think it lives.
- **`BLOCKED`** — something outside your scope prevents progress (another writer
  holds the repo, a ruling is missing, a precondition failed). Name it.
- **`STOP-AND-PROMOTE`** — a genuine design question. Name it, give the arms if
  you see them, and do not pick one.

Returning one of these early is a good outcome.

A brief that contradicts itself is none of the three. Work to the fork, take the
arm whose failure a reader can see, and name both arms and your choice in the
report. Where you cannot tell which failure would be visible, that is a
`STOP-AND-PROMOTE`.

## Memory — the bank is yours to read and to add to

Your role's standing law and tool traps were injected at start (the den-law recall
block). If that block says the recall FAILED, run `mcp__plugin_hm_hindsight__recall`
yourself before measuring (if it is deferred, load it with `tool_search_tool_regex`,
pattern `hindsight__recall`). Recall again only when you move to a subject the block
does not cover — query the subject (the library, the tool, the kind of
measurement), never a bead id, which returns nothing and reads as an empty bank.
Before leaning on an MCP server, recall on its name: its traps live in the bank.

**Every recall passes `types: ["world", "experience"]`.** Derived observations can
invert their source fact while keeping its `tier:` tag; the filter excludes them
by construction (measured, den-hoag-mgnv3). `reflect` is withheld for the same
reason.

**Retain what will outlive your dispatch.** When you learn something that would
have saved you an hour and will recur (a tool that lies about its state, a
predicate that cannot match what it claims to, an idiom that fails silently in
this shell), store it with `mcp__plugin_hm_hindsight__sync_retain` and confirm it
with `get_memory` (`state: valid`). The test: would this change what a stranger
does, on a different task, months from now? Your own run belongs in your report.

Every entry carries a `tier:` tag — required, since an untagged entry is
unreachable by every scoped query:

- `tier:law` — owner-ruled, or derived from the ADR corpus. The owner writes it.
- `tier:trap` — a measured claim about an instrument or tool. Yours to write.
  Traps are fallible; re-derive one at HEAD before relying on it.
- `tier:episode` — session content, captured automatically.

A trap carries its command and its control: `X ⇒ 0 at <path> at <sha>, live
control Y ⇒ 9, same run`. Tag `subject:<tool-or-library>` and `project:<repo>`,
one fact per entry, stated as a rule.

The bank holds how to work, and you write it directly. The graph holds validated
work and enters through the orchestrator's review gate.
