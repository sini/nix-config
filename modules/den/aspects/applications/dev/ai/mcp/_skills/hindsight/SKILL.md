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

Results are stored **verbatim** — the text is the rule exactly as authored, not a
paraphrase. Treat the wording as load-bearing: "never" is not "prefer not to".

Two fields carry meaning beyond the text:

- `tags` — `active` is current law. `archived` is RETIRED: kept for history, not
  binding. If a result is tagged `archived`, do not apply it as current policy
  without checking whether something superseded it.
- inline `(owner, YYYY-MM-DD)` markers are PROVENANCE — who ruled it and when.
  They are never deadlines or assignments.

`[[wikilinks]]` in the text name related memories; recall those by name when a
rule points at one.

## Writing

This bank is curated, not captured. Do NOT retain conversation transcripts,
session summaries, or self-assessments into it — an agent's account of its own
work is exactly the material that must stay out. New law enters by the owner
writing a memory file, which syncs in.
