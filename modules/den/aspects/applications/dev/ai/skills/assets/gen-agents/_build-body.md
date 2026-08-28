## How to land

1. **Baseline before you change anything**, so you can attribute every later
   red. Record what you got; do not inherit a figure from the spec.
2. Implement the spec's mechanism.
3. Re-run the suites and **attribute every delta**.
4. **Verify the artefact changed before you read any suite.** A scripted edit
   that throws part-way can roll back every replacement and leave the tree
   untouched; the suite then returns the _old_ tree's numbers and they look like
   success. Diff, or check the mtime, or grep for the new text — then measure.
   This also guards the next step: **the seed is itself an edit with the same
   failure mode.** A seed that silently no-ops leaves the cell green, and the
   honest reading of that green is "this cell does not discriminate" — so you
   would file a finding against a sound cell.
5. Run the spec's acceptance cells, then **drive each one RED and read the
   output**. Break the thing the cell claims to catch — replace the message with
   a sentinel, restore the removed guard, delete the arm the cell names — and
   confirm the cell actually fails. A cell you have only ever seen green has not
   been shown to discriminate. A red/green table you were handed was evaluated
   against the tree as it stood before your edit — inheriting it is relaying, not
   measuring.

★ **An unexpected red is a FINDING, not a fixture to update.** If a cell flips
that the spec did not enumerate, **stop and report it**.

## Landing discipline

- **Format first**; a first-pass non-zero exit means it changed files, so re-run
  until clean.
- **Commit path-scoped**: `git -C <repo> commit -m "…" -- <explicit paths>`.
  Never `git add -A`, never `git add .`, never a bare `commit` (it takes the
  whole index), never `--amend` without a pathspec. A bare commit has swept
  another writer's staged work into a push.
- **No `Co-Authored-By` and no `Claude-Session:` trailers**, in any commit,
  ever.
- `git add` new test files **before** the collecting run — untracked test files
  are silently absent from a suite, which reads as a clean pass.
- Push, then re-verify clean and matching origin **at the final landed
  revision**.
- ★ A push moves the whole branch, not your paths. If anything unexpected is
  committed locally, stop.

## Working with terse feedback

Expect short corrections. You hold the spec and the session context, so two
words are often enough: _"Wrong repo."_ · _"Path-scope it."_ · _"That red is a
finding."_ Do not over-interpret a terse correction into a larger redesign —
apply exactly what it says and continue.

## Revert and re-scope

★ **When an approach goes wrong, do not patch it forward.** Say so and let the
orchestrator revert. Narrowing scope after a revert reliably beats incrementally
repairing a bad approach — and a half-repaired approach is harder to judge than
a clean one. After a revert, implement only what is explicitly asked.

## Reference existing code

When told to match an existing pattern, **read the referenced files first**. A
pointer to a working sibling carries the implicit requirements — naming, error
shape, test placement — that a description would miss.

## Hand off

- The spec is wrong or incomplete → **gen-spec**. Do not design around it.
- You need a measurement you cannot take within scope → **gen-scout**.
- Your landing needs judging → **gen-gate**.
