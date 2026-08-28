# gen-agents — the agents are COMPOSED, not stored

There is no `gen-scout.md` in this directory and there should not be. Each of
the four agents is assembled at build time by `../../gen-agents.nix`:

    _<role>-head.md  +  _shared-measurement.md  +  _<role>-body.md  +  _shared-protocol.md

So: **editing `_shared-measurement.md` or `_shared-protocol.md` changes all four
agents at once.** That is the point, and it is also the hazard — check the blast
radius before you touch either.

| file                     | reaches                                                              |
| ------------------------ | -------------------------------------------------------------------- |
| `_shared-measurement.md` | all four — instrument facts, measurement law, reporting              |
| `_shared-protocol.md`    | all four — the dispatch protocol                                     |
| `_<role>-head.md`        | one — frontmatter (name/description/tools) and the role's opening    |
| `_<role>-body.md`        | one — the role's own sections, through "Hand off"                    |
| `DISPATCH.md`            | nobody — a template for the orchestrator, deliberately not installed |

## Why it is split

Measured 2026-08-27 across the four then-separate files: **103 lines were
identical, 57% of their total.** Every fix cost four edits, and in one editing
round that produced two divergences — including a rule copied without the
measurement that justified it, leaving a bare assertion in files that require
claims to carry their evidence. Discipline was not holding it; composition does.

The trade is real and runs the other way too: one editing slip now reaches four
agents instead of one, and a contradiction between a shared rule and a role's
own text is no longer visible in a single file read. Both happened during the
split itself. Prefer changing a `_<role>-body.md` when the change is genuinely
role-specific, and do not tailor the shared block per role — that reintroduces
exactly what this removes.

## Checking a change

The generated agents are the artefact; the fragments are only their source. Read
what an agent will actually receive:

    nix build --no-link --print-out-paths \
      '.#nixosConfigurations.<host>.config.home-manager.users.<user>.programs.claude-code.agents.gen-scout'

Composition order is load-bearing and was wrong twice while this was built — the
shared block after the role body, then a missing blank line at each join. Both
were caught only by diffing the generated file against the previous one. If you
change `mkAgent`, diff before and after rather than trusting that it evaluates.
