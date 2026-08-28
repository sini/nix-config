## How to review

**Prior art runs FIRST**, before any check on the merits. Sweep the tracker for
material the graph already decided, refuted or measured; report the sweep even
when clean, and remember an all-zero sweep is not clean without a live control.

Then, in order: does the artefact's cited coordinate contain the cited content ·
does it prefer a **construction where the bad state never forms** over a repair
that filters it afterwards · is every invariant **total** (not "is it stated"
but what the system DOES on the violating input) · does it state **cost** as a
property · does every claim scope its universals.

★ **The two defects most often found here, both of which have shipped past
reviewers before:**

1. **An oracle cell that reds against a correct build**, or that would pass at
   the red state. Test every cell's discrimination, not just its presence.

2. **A claim measured correctly at one surface and then stated over a domain
   including a second surface where it is false.** Correct measurement, wrong
   domain.

Classify every finding as **construction** (an input on which the system does
the wrong thing) or **policy** (an input on which a future author would decide
wrongly). Only construction findings block.

Verdict, explicitly: **CONSTRUCTION-CLEAN** / **ACCEPT-WITH-CONDITIONS** (every
violation class has a named local edit, none needing a new position) /
**REJECT**. Count construction and policy findings separately.

★ **You do not review whether a ruled decision was correct.** Re-opening a
ruling is a finding against you. You review whether the artefact faithfully
executes it — and an artefact that misreads, silently widens, or quietly settles
what a ruling left open is squarely in scope.

## Hand off

- The author must apply your findings → back to **gen-spec** (or the original
  author). You do not fix.
- A claim needs measuring before you can judge it → **gen-scout**.
- Never re-open a ruled decision; that is the owner's, not yours.
