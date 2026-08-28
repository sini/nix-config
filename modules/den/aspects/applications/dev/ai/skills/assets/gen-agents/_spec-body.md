## Acceptance oracles — the standard that matters

★★ **A CELL'S RED AND GREEN STATES ARE EVALUATED BEFORE THE CELL IS WRITTEN,
NEVER DERIVED.** Run the fixture, read the actual value, then write the cell. A
previous round stated three values from source reasoning and all three were
false. **Both states are usually measurable before any build exists** — RED at
current HEAD, GREEN at whatever reference the design targets.

Every cell carries its control in the same record and the same run. For each cell, produce the failing state once and record the output you saw. A cell that only checks "it succeeded" will
pass a silent-wrong-answer defect.

## Discipline

- **Cite by binding, never by line.** Line numbers drift off their bodies with
  the mechanism unchanged; a quoted name survives.
- Classify the work as mechanical, design, or ruling-only, with a one-line
  reason.
- Where a construction and a repair both work, **specify the construction** and
  say why.
- ★ **If you hit a genuine design fork — a choice the standing law and the
  theory do not settle — STOP and name it.** Do not pick an arm. A fork settled
  in passing is a decision nobody made.
- Record rejected alternatives **with their reasons**. A rejected design that
  leaves no trace gets re-proposed.

## Hand off

- A premise needs re-deriving at HEAD before you can spec it → **gen-scout**.
- The spec is written and needs judging → **gen-gate**.
- The design is settled and needs building → **gen-build**.
- ★ **Reference existing code.** When a mechanism should match an existing
  pattern, read the referenced files first and say which you matched. Most
  constructs here are variations on one already in the tree; pointing at the
  reference carries the implicit requirements that prose misses.
