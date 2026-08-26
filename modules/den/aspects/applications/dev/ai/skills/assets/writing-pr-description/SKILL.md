---
description: Writes GitHub PR descriptions in a terse, opinionated style. Delegates body shape to the repo PR template when one exists; falls back to `## Summary` plus an optional ad-hoc validating-changes block. Never mutates an existing checklist. A change carrying more than one reviewable concern is stacked by default, one PR per concern, via the `gh-stack` skill. Use when drafting a `gh pr create` body, opening a PR, or when the user says 'PR body' / 'pull request description'.
model: haiku
effort: low
---

# Opinionated PR descriptions

A prescriptive style guide for GitHub PR bodies. The repo PR template always
wins; the defaults below are the fallback when none exists. Each rule pairs the
correct shape with the form it replaces.

Provenance: derived from a personal-OSS corpus of 295 PRs authored before
2024-06-01, plus the standing rules in `~/.claude/CLAUDE.md`.

## Decision routing

```
Change carries more than one concern?    -> stack it; `gh-stack` skill owns the shape
Repo has a PR template?                 -> fill it verbatim; add no sections, no checklist items
No template?                             -> ## Summary + optional ## Validating Changes
Change tracks an external issue?         -> issue URL alone on line 1, nothing before it
Behavior hand-verified, not by tests?    -> add the Validating Changes block
Creating the PR?                          -> gh pr create --web; never auto-submit
```

Stacked is the default shape for a change with more than one reviewable concern,
which is the same rule as one concern per commit. One PR per concern, each based
on the one below. Route to the `gh-stack` skill for the commands; the body of each
layer is still written here. A change with one concern is an ordinary PR: a stack
of one is just a PR.

## PR title

A PR title is a commit subject, so compose it with the `writing-commit-message`
skill. The shape is `<type>(<scope>): <TICKET>: <description>`, with the ticket
after the scope and before the description, never as a trailing suffix. PR-specific addition:
multiple tickets join with `/` (`INF-2291/INF-2493`).

## First, read the repo's contribution docs

Repo-specific rules override these defaults. Sweep before drafting:

```bash
ls CONTRIBUTING.md .github/CONTRIBUTING.md docs/CONTRIBUTING.md 2>/dev/null
ls .github/CODEOWNERS CODEOWNERS DCO .github/DCO 2>/dev/null
grep -l "Signed-off-by\\|DCO" CONTRIBUTING.md .github/* 2>/dev/null
```

Extract the required commit format and issue-link syntax, plus branch naming.
Extract whether an issue link or a "How to test" section is mandatory. Extract
which CI checks gate merge, the CODEOWNERS reviewers, and any DCO or
`--signoff` requirement. When `CONTRIBUTING.md`
conflicts with the defaults below, the repo wins.

## Use the repo PR template verbatim when one exists

```bash
ls .github/pull_request_template.md .github/PULL_REQUEST_TEMPLATE.md \
   .github/PULL_REQUEST_TEMPLATE/ docs/pull_request_template.md \
   PULL_REQUEST_TEMPLATE.md 2>/dev/null
```

The template's structure is canonical. Fill its sections; leave its structure alone.

```
# good — template defines ## Summary + a 3-item checklist
## Summary
- <one bullet>
## Checklist
- [x] tests pass
- [ ] docs updated
- [ ] changelog entry        (exactly the three the template defines)

# bad
## Summary
...
## Risks            <- invented section not in the template
## Checklist
- [x] tests pass
- [ ] docs updated
- [ ] changelog entry
- [ ] new: security review   <- appended a fourth checklist item — forbidden
```

Only check or leave the existing `- [ ]` items; never append new ones, even when
the change seems to warrant one.

## How to create the PR: exact form

```bash
gh pr create --web \
  --title "<conv-commit-style title>" \
  --body "<body content>"
```

For a stack, `gh stack submit` replaces this form and stays owner-gated the same
way. Each layer gets its own body written by these rules, and only the bottom
layer carries the issue URL.

`--web` opens the pre-filled web editor so the user reviews, sets labels and
reviewers, and submits. Never use these by default: `--draft`, `--fill` /
`--fill-first`, `--reviewer` / `--assignee` / `--label`, or submitting without
`--web`. Never auto-submit (draft or ready) unless the immediately preceding user
turn explicitly directed it.

## Top-line: issue URL alone on line 1

```
# good
https://linear.app/<workspace>/issue/PROJECT-NNN/<slug>

## Summary
- ...

# bad
Fixes: https://linear.app/...    <- no prefix; the bare URL leads
```

Use `Closes #NN` / `Fixes #NN` suffixes only when the PR fully closes that issue.

## Fallback structure when no template exists

````markdown
https://linear.app/<workspace>/issue/PROJECT-NNN/<slug>

## Summary

- <one-sentence bullet>
- <one-sentence bullet>

## Validating Changes (ad-hoc, if logic is not covered by automated tests)

- <one-sentence bullet describing what was hand-verified>
````

Use only `## Summary` and at most `## Validating Changes (ad-hoc, if logic is not
covered by automated tests)`. Do not invent `## Risks`, `## Test plan`,
`## Description`, `## Motivation and context`, or `## Types of changes`, those
are auto-template defaults or post-corpus inventions.

## Summary bullets: good vs bad

```
# good, one sentence per bullet, identifiers backticked, causal `so`/`as`/`because`
- Removes the `aws-knowledge` MCP server as it is no longer used.
- Defaults structural search to `ast-grep` so agents stop approximating code shapes with regex.

# bad
- This PR adds a bunch of changes, it removes the server and also...   <- preamble + em-dash + multi-clause
- Search: now uses ast-grep                                         <- bolded list row
```

The shortest acceptable bullet for a self-evident PR is `See title.`. For a PR
spanning many distinct areas, group bullets under area subheads with a trailing
colon, such as `Schema:`, `Permissions:`, and `Testing:`. Do not use a flat
list of multi-sentence bullets.

## Show a rerouted call path, do not describe it

A change moves control flow when it adds a call path, drops one, or reroutes a
caller. Run `calldiff diff <base> --max-depth 3` and put the plain tree in a
fenced block under `## Summary`, below the bullets. The tree is shorter than the
paragraph, and a reviewer can check it. Then delete the bullet that was
describing the same thing in prose.

This is a block inside `## Summary`, not a new section. Do not add a
`## Call graph` heading; the rule against invented sections still holds. Skip it
for a Nix-only change, which calldiff cannot parse, and for a change that only
edits bodies without moving edges. Load the `calldiff` skill for the flags.

````markdown
<!-- good, the tree carries the claim -->
## Summary

- Routes clipboard restore through `panel.hide()` so the panel closes before the paste lands.

```
  activate(choice)
+ ├─ panel.hide()
  └─ clipboard.restore(row.entry)
```

<!-- bad, a paragraph doing the tree's job, and an invented section -->
## Call graph

Previously `activate` called `clipboard.restore` directly, but now it first
calls `panel.hide()`, which changes the ordering such that...
````

## Validating Changes section

Optional. Use only when behavior was hand-verified rather than covered by tests.
Header is literally `## Validating Changes (ad-hoc, if logic is not covered by
automated tests)`. Bullets are past tense, describing what was actually done. If
nothing was hand-verified, omit the section, do not leave an empty placeholder.

## Never

- Paste a generic GitHub template over an existing repo template.
- Preamble (`This PR adds…`, `In this change…`), lead with the action.
- Tool-attribution / `Co-authored-by Claude` trailers unless the user opted in.
- Architecture overviews, which belong in the change's `design.md`.
- Em-dashes for elaboration, use `so`, `as`, `because`.
- Emojis, anywhere.
