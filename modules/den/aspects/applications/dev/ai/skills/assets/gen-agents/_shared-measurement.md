## Instrument facts — each has caused a real false finding here

Shell and tracker facts every run needs. Traps specific to one MCP server live in
the bank (see Memory, below).

- **The shell is zsh, not bash**, despite the tool's name. `$pipestatus`, not
  `$PIPESTATUS`. Brace a rev:path — `"${sha}:lib/x.nix"`; the bare form applies
  zsh's history modifier and can return nothing while exiting 0. Unquoted
  `$list` does not word-split.
- **Never name a variable `path`** — it is tied to `PATH`, and assigning it makes
  every external command vanish silently. `status` is read-only.
- Use `/run/current-system/sw/bin/grep` for any count you report; the wrapper
  `grep` honours `.gitignore` and under-reports. `grep -r` does not follow
  symlinks; `-R` does.
- `grep -c` counts matching lines, and prose wraps, so a multi-word phrase reads
  0 while present. Flatten and squeeze: `tr -s '[:space:]' ' ' | grep -o 'phrase'
  | wc -l`. `-c` counts lines, `-o | wc -l` occurrences, `-rc | wc -l` files —
  carry the unit in the figure.
- Read exit status unpiped: `cmd > file; echo $?`. Piping through `tail` gives
  `tail`'s status.
- `2>/dev/null` turns a missing instrument into an absence finding. Do not
  silence stderr on a measurement.
- `nix eval` leaves the spine unforced — use `deepSeq`. Run every nix eval, build
  and check under `systemd-run --user --scope -q -p MemoryMax=12G <cmd>`; rc 137
  under the cap is a finding, never a reason to re-run uncapped.
- Suites live at `./ci#tests`, not the root flake. **`0/0` is a false pass.**
  Count both ❌ and ☢️, and check the collected-cell count agrees with the summary.
- Read tracker bodies with `STATUS/br-cat.sh <id>`, never a bare `br show` (48x
  slower, re-imports comment sediment). `br list --json` wraps rows as
  `{"issues":[…]}`; a bare `.[]` reads empty.

## Measurement law

- **Every absence claim needs a positive control that fired, in the same
  instrument and the same run.** A control that returns nothing is a broken
  instrument; a zero from a predicate that could not have matched is invalid.
- Check a predicate's reach against the concept, not its spelling: a true zero in
  the wrong library or under the wrong term is a confident wrong answer.
- **Drive the check red and read it.** Produce the failing state and look at the
  output; a check never seen to fail has not been shown to discriminate (a build
  whose edit wrote nothing returned `163/163` and was read as success).
- A probe whose two arms agree has measured nothing, and nor has a one-armed probe
  compared against a figure in a document. A finding that overturns a claim
  exhibits both arms, from your own instrument, in one run, measuring the same
  object. A primary source may stand in for an arm; an assertion may not.
- A report about an artefact is never a measurement of it. Re-derive; do not relay.
- **Your brief is a claim set, not ground.** Load-bearing brief claims were false
  in about half of sampled runs — stale, or simply wrong about a live count, path,
  cause or coordinate. Test them before building on them; confidence markers do
  not protect a claim.
- Coordinates drift, and "at HEAD" is not one. Re-derive any cited line, digest or
  path and say which copy you read; where a pin exists (`/nix/store`, a lock file,
  a sha), read the pinned rev, not the working tree.

## Reporting

State what you evaluated versus what you derived; never present a derivation as a
measurement. A partial result reported as partial is useful; reported as complete
it is worse than nothing.

Three disclosures are owed: (1) a premise of your brief you falsified — lead with
it; (2) a measurement you re-ran because the first was broken — both runs and the
retained probe's path; (3) files you wrote through a shell heredoc or script —
by path, since they are invisible in your trace.

**A negative-control token is generated per run and never written down**
(`/dev/urandom`, a uuid fragment, `$RANDOM`); report its count and method, never
the string. A token quoted in any document is already in the corpus, so treat a
sweep that quotes a literal token as suspect until you check the corpus for it.
