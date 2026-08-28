# writing-tone: what the rules rest on

Not loaded at invocation. This is the maintainer's record: it exists so a later
editor can tell an observed habit from a guess, and so a rule is not "corrected"
back to something the corpus refutes.

Measured 2026-08-28, one predicate set, one run. Unit is a message for the chat
corpora and a paragraph for the documents.

| unit = message / paragraph | community | working | long-form | formal | personal |
| -------------------------- | --------- | ------- | --------- | ------ | -------- |
| n                          | 3173      | 880     | 49        | 160    | 14       |
| starts lowercase           | 60%       | 31%     | 0%        | 0%     | 0%       |
| contractions               | 34%       | 32%     | 84%       | 14%    | 71%      |
| hedges                     | 9%        | 6%      | 37%       | 4%     | 50%      |
| semicolons                 | 6%        | 21%     | 69%       | 6%     | 0%       |
| `--` as a dash             | 8%        | 13%     | 55%       | 0%     | 29%      |
| ellipsis `...`             | 5%        | 0%      | 22%       | 0%     | 57%      |
| "you/your"                 | 23%       | 22%     | 57%       | 4%     | 36%      |
| emoji                      | 10%       | 0%      | 2%        | 0%     | 0%       |
| exclamation                | 1%        | 0%      | 0%        | 0%     | 0%       |
| median sentence            | 131       | 91      | 113       | 137    | 60       |

Sources, with where to re-derive them -- the working files were session
scratch and are gone, so a re-check means rebuilding from these:

- **3,173 support-channel messages**: a local JSON export of the den support
  channel, filtered to this author's own sender id and reduced to message
  bodies. The export holds other participants' messages and is not published.
- **880 working instructions + 49 long-form**: user turns in the Claude Code
  transcripts under `~/.claude/projects/*/`.
- **two pre-LLM documents**: a UI design report and a database-theory answer
  set, supplied by the owner in session.
- **two authored survey papers**: supplied by the owner in session.
- **one private correspondence**: supplied in session, measured for prosody
  only, redacted and not retained. Not re-derivable, deliberately.

A reviewer flagged 2026-08-28 that these figures are the least verifiable in the
change, because the corpora were not identified by path. The commit-corpus
figures in `writing-commit-message/PROVENANCE.md` reproduced independently; these
did not get the same treatment.

## Under load

Median sentence drops 113 -> 60 characters, 41% of sentences fall under 50, and
semicolons go to zero. This is the sharpest signal in the corpus.

## Two rules were falsified and corrected

Both had been stated as absolutes by an earlier version of this guide.

- **Exclamation marks** were recorded as "zero across 4,100 messages". True
  figure: 21 community messages (1%), all short social exclamations. Zero in
  every other register.
- **Em-dashes** were banned outright. `--` merely dominates, 55% against 12% in
  long-form. Both papers' only `—` is the IEEE `Abstract—` header, which is the
  template rather than the writer.

An unscoped "never" in `SKILL.md` should be treated as unverified until someone
re-runs the predicate.

## The technical register is read, not counted

Prosody metrics found nothing distinctive in the papers beyond genre convention.
The habits that make them his -- cost attached to every claim, scope fenced in
place, provenance bound to every borrowed assertion, budget spent on history --
are visible only on reading. No counting predicate would have surfaced them.

## Excluded, deliberately

- **GitHub issue comments**: they mix human and model-generated text. A style
  corpus contaminated with model output teaches the model to imitate itself.
- **The personal-register source**: measured for prosody only, every name
  redacted before it touched disk, and not retained. This repository is public.
  The `<good>` example in that register is a constructed paraphrase carrying the
  measured shape. The worked example that carried it was **cut on owner
  instruction 2026-08-28**: it read as testimony from a real incident and this
  repository is public. The register is now stated as guidance only -- honest,
  open and direct -- with no example.
