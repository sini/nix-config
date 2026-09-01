---
name: hindsight
description: Recall standing operating law from the den-law memory bank — the fleet's rules, preferences and constraints on how work is done. Use BEFORE acting when a task touches process, tooling, git, review, dispatch, formatting, secrets, or anything the owner has previously ruled on. Triggers on: what's the rule for, how do we do X here, have we decided, is there a convention, what did the owner say, did we rule on, standing law, prior ruling, our policy on.
---

# Hindsight — standing operating law

`den-law` holds the fleet's operating law: rules the owner has ruled on, why they
exist, and when they apply. It is not a log of what happened.

## When to recall

Recall BEFORE acting, not after being corrected. The cost of a recall is a few
hundred milliseconds; the cost of missing a standing rule is rework the owner has
already paid for once.

Recall when a task touches:

- process — spec-first, gates, reviews, dispatch, task status
- git — staging, commit shape, bylines, merge and push policy
- tooling — which instrument to reach for and its known traps
- verification — what counts as a measurement, what controls are required
- formatting, secrets, naming, or any repo convention

Do NOT recall for pure code mechanics with no policy dimension.

## How to read a result

Check `type` FIRST. A `world` fact is the owner's text stored **verbatim** — the
rule exactly as authored, not a paraphrase — so treat its wording as load-bearing:
"never" is not "prefer not to". An `observation` is the engine's synthesis OF
those facts. It is a pattern worth checking; it is not law and must never be
quoted as a ruling.

The recall hook prints the two under separate headers. The MCP `recall` tool does
NOT — there you get raw results, and `type` is the only thing distinguishing
owner law from machine paraphrase. Pass `types: ["world"]` if you want law only.

Three fields carry meaning beyond the text:

- `type` — `world` is owner-authored. `observation` is synthesised from `world`
  facts and carries no authority of its own.
- `tags` — `active` and `archived` are both LAW. `archived` mostly records
  capacity management, not retirement: a rule was moved out of the always-loaded
  index because that index has a size budget, which says nothing about whether
  the rule still binds. Do NOT discount an `archived` result for being archived.
  Retirement is stated in the text itself — a rule that no longer binds says so,
  and names what replaced it. Read the text, not the tag.
- inline `(owner, YYYY-MM-DD)` markers are PROVENANCE — who ruled it and when.
  They are never deadlines or assignments.

`[[wikilinks]]` in the text name related memories; recall those by name when a
rule points at one.

## Writing

This bank is curated, not captured. Do NOT retain conversation transcripts,
session summaries, or self-assessments into it — an agent's account of its own
work is exactly the material that must stay out. New law enters by the owner
writing a memory file, which an agent then retains BY HAND — no unit in the
deployment does it, so the bank is only as reviewed as that run was.

Nothing stops you mechanically. The bank's `mcp_enabled_tools` allowlist is
unset, so `retain`, `update_bank` and `clear_memories` are all exposed to you.
This section is the only thing holding that line.
