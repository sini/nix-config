# writing-commit-message: what the rules rest on

Not loaded at invocation. Maintainer's record.

Measured 2026-08-28 over 8,214 non-merge commits authored by this user across 41
local repositories. Not a third-party corpus; the previous version of this skill
was derived from a different author's 295 PRs and 504 commits.

## The corpus splits, and the split decides which half to trust

|                    | 2025 (n=1,259) | 2026 (n=6,954) |
| ------------------ | -------------- | -------------- |
| em-dashes          | 0.0%           | 27.9%          |
| bodies             | 2.4%           | 47.9%          |
| subject > 72 chars | 0.2%           | 51.8%          |
| median subject     | 24 chars       | --             |

A step change, not a drift, and 2026 is when the agent-heavy workflow started.
Its direction is toward model defaults. **The 2025 half is the voice oracle; the
2026 half is what this skill exists to correct.** Building the rules from the
aggregate would have encoded the model's habits as the author's.

## Two axes, not one

The 2025 corpus is in-voice *and* under-informative. Real subjects from it:
`stash`, `remove cruft`, `fix media target`, `update facts for cortex`. A median
of 24 characters cannot name what changed.

So the voice rules in `SKILL.md` are descriptive and the information rules are
normative. Do not resolve the tension by imitating the shorter thing. This was
an explicit owner ruling, 2026-08-28: *"Jason the human is lazy, his commits are
terse and uninformative -- a middle ground might be optimal."*

## Other measured figures

- lowercase subject: 99.0%
- conventional `type:` prefix: 20.5% in 2025, so a bare imperative subject is
  the ordinary form rather than a fallback
- trailing period: 1.7%
- backticks in the subject: 0.0%
- uppercase `PROJECT-NNN` ticket ids: **0.0%**. The previous version of this
  skill claimed 83% and made the ticket variant the default. That figure came
  from the other author's corpus.
- beads ids (`den-hoag-xxxx`) in subjects: 1.8% across the whole corpus

## Standing-law violations found in history

All in the 2026 half: 78 commits carrying `Claude-Session:`, 14 carrying
`Co-authored-by:`, 6 carrying `Generated with`. The ban is not new; it was not
being enforced.

## Owner ruling on body content, 2026-08-28

*"Commit messages should be long enough to describe what, with a hint of why
where it is relevant to understanding why what was needed -- not an essay or
full log. New features almost never need a why; bug fixes are self explanatory.
Only when something is genuinely unintuitive do we need to spend time in the
commit to explain why."*

This supersedes an earlier draft rule that said to write a body whenever the why
was "not readable from the diff". That bar was far too low: almost every change
has a why the diff does not show, and almost none of them need it written down.
The bar is **unintuitive**, not merely **unstated**.
