---
description: 'Structures a technical design doc from the Kubernetes KEP skeleton: Summary, Goals/Non-Goals, Proposal, Design Details, Validation, Drawbacks, Alternatives. Use when the open question is HOW to build something already agreed on, not whether to. When the question is whether or which, use `writing-doc-rfc` instead. Use when drafting or reviewing a design doc or technical proposal.'
---

# Writing a design doc

A structure and voice guide for technical design docs, documents that describe
*how* something will be built once the direction is broadly agreed. The skill
owns the section skeleton and the prose voice; the author owns the content.

Provenance: the section skeleton comes from the Kubernetes KEP template,
`kubernetes/enhancements`, `keps/NNNN-kep-template`. It drops the
Kubernetes-specific machinery: release signoff, graduation criteria, version
skew, the production-readiness questionnaire, and feature gates. It is tuned to
Roshan's working voice.

## Decision routing

```
Open question is *how*, not *whether*?          -> design doc (this skill)
Open question is *whether* / *which*?            -> writing-doc-rfc instead
Change small enough the PR description carries?   -> skip both
Where does it land?                               -> see Step 0
```

<!-- include: doc-destination.md kind=design -->

<!-- include: doc-voice.md -->

```
# good — leads with the finding, claim paired with how it is validated
The cache cuts cold-start p99 from 1.8s to 320ms, confirmed in the load test (k=500).

# bad — throat-clearing, unvalidated marketing claim
This document describes a robust, seamless caching layer that should improve performance.
```

## The skeleton

Sections in order. Drop a section only deliberately, and say why if its absence
would surprise a reader.

1. Summary: One paragraph. What this builds and why, readable on its own.
   Write it last; lead with the outcome.
2. Motivation: The problem as it is. Concrete, not abstract.
   - Goals, what success looks like, as observable outcomes.
   - Non-Goals, the explicit out-list. The most load-bearing subsection.
3. Proposal: The shape of the solution at a glance, before the detail.
   - User stories / workflows *(optional)*, who does what, end to end.
   - Notes, constraints, caveats, what bounds the design.
   - Risks and mitigations, what could go wrong and the answer to each.
4. Design Details: The technical core: data shapes, interfaces, control
   flow, edge cases. Diagrams here earn their place (use the diagram skill).
   - Validation, how each claim is checked. Give the tests, the manual steps,
     and the inverse case that proves the boundary holds. Generalized from the
     KEP "Test Plan"; no unit/integration/e2e ceremony unless it fits.
   - Rollout / migration *(optional)*, how it ships and how it rolls back.
5. Drawbacks: Honest reasons not to do this. If you cannot name one, the
   analysis is incomplete.
6. Alternatives: Other designs considered and why each was rejected. This
   is where reviewers look first; treat it as load-bearing, not an appendix.
7. Dependencies / resources needed *(optional)*, what this needs from
   other people or systems. Generalized from KEP "Infrastructure Needed".
8. Implementation history: A lightweight changelog: created, revised,
   accepted. Append-only.

## Doc frontmatter

A trimmed version of the KEP `kep.yaml` metadata, drop kep-number, SIGs,
feature-gates, milestones, stage.

```yaml
title: <short imperative title>
authors: [<name>]
status: draft        # draft | under-review | accepted | superseded
created: <YYYY-MM-DD>
reviewers: [<name>]  # optional
see-also: []         # links to related docs
supersedes: []       # docs this replaces
```

## Template (copy-paste)

````markdown
# <Title>

> Status: draft · Authors: <name> · Created: <YYYY-MM-DD>

## Summary

<One paragraph: what this builds and why.>

## Motivation

<The problem, stated concretely.>

### Goals

- <observable outcome>

### Non-Goals

- <explicitly out of scope>

## Proposal

<The solution shape at a glance.>

### Notes, constraints, caveats

- <what bounds the design>

### Risks and mitigations

- Risk: <x>. Mitigation: <y>.

## Design Details

<Data shapes, interfaces, control flow, edge cases.>

### Validation

- <claim> — checked by <how>; inverse: <what proves the boundary>.

### Rollout / migration

<How it ships and rolls back. Omit if trivial.>

## Drawbacks

<Honest reasons not to do this.>

## Alternatives

- <alternative> — rejected because <reason>.

## Dependencies / resources needed

- <what this needs from elsewhere>

## Implementation history

- <YYYY-MM-DD> created
````

## Checklist before sharing

- Summary reads on its own, no jargon undefined.
- Non-Goals lists at least one real exclusion.
- Every claim in Design Details pairs with a Validation line.
- Alternatives names every rejected option and the reason it lost.
- At least one honest Drawback.
- No emojis, no marketing adjectives, no rhetorical flourishes.
- Destination decided (Notion private vs `.sysinit/`) and stated.
