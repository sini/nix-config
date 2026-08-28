# gen-agents: the four recurring subagent roles of the gen/den architecture effort,
# declared once instead of re-typed into every dispatch prompt.
#
# ★ WHY THIS EXISTS. Orchestration in this project dispatches fresh-context agents, and
# every dispatch was carrying the same ~25-line block of instrument facts — zsh is not
# bash, `grep -c` counts lines, `0/0` is a false pass, an absence needs a live control.
# That block is the part most likely to be dropped under pressure, and dropping it
# produces exactly the failures it warns about (measured: an empty control that read as
# a pass; coordinates read at a working clone instead of the locked rev). Declared here,
# it cannot be forgotten; a dispatch prompt then carries only what is task-specific.
#
# ★ TOOL RESTRICTION IS THE POINT WHERE IT ACTUALLY BINDS, and it does not bind
# everywhere. `gen-gate` has no Edit: a reviewer that cannot Edit cannot quietly repair
# the artefact it is judging, and that is a construction rather than a discipline.
# `gen-scout` DOES have Write, changed 2026-08-27 on measured grounds: withholding it
# never prevented writing, because Bash heredocs write just as well. In 10 of 29 sampled
# subagent transcripts they did, invisibly, so the trace read "read-only" for runs that
# had written files. Unobservable writing is worse than declared writing. What binds
# gen-scout is no Edit — it may create probes and reports, never revise the artefact
# under measurement.
#
# Frontmatter is Claude Code's own schema — name / description / tools / model. Note that
# opencode-style keys (`mode`, `temperature`, nested tools+permission maps) are silently
# ignored here and are deliberately absent.
#
# ★ THE SHARED HALF IS SINGLE-SOURCED, and that is a correctness property rather than
# tidiness. Measured 2026-08-27: 103 lines were identical across all four role files,
# 57% of their total, so every fix cost four edits — and two drifts were introduced in
# a single editing round, including one where a rule was copied without the measurement
# that justified it. Each role is now `head + shared-measurement + role body +
# shared-protocol`, composed below, so the shared text cannot diverge by construction.
{
  den.aspects.applications.dev.ai.skills.gen-agents = {
    agent-extensions =
      { pkgs, ... }:
      let
        d = ./assets/gen-agents;
        shared = builtins.readFile "${d}/_shared-measurement.md";
        protocol = builtins.readFile "${d}/_shared-protocol.md";
        # Order matters and is verified: head, then the shared measurement block,
        # then the role body, then the shared protocol. Concatenating head+body
        # first puts the shared half in the wrong place — caught by the
        # byte-identity check against the hand-maintained files.
        mkAgent =
          role:
          pkgs.writeText "gen-${role}.md" (
            builtins.readFile "${d}/_${role}-head.md"
            + "\n"
            + shared
            + "\n"
            + builtins.readFile "${d}/_${role}-body.md"
            + "\n"
            + protocol
          );
      in
      {
        type = "skill";
        agents = {
          gen-scout = mkAgent "scout";
          gen-gate = mkAgent "gate";
          gen-spec = mkAgent "spec";
          gen-build = mkAgent "build";
        };
      };
  };
}
