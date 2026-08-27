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
# ★ TOOL RESTRICTION IS THE POINT, not decoration. `gen-scout` has no Edit and no Write,
# which turns the standing rule "an audit that edits as it goes cannot report what it
# found" from a discipline into a construction. Same for `gen-gate`: a reviewer that
# cannot Edit cannot quietly repair the artefact it is judging.
#
# Frontmatter is Claude Code's own schema — name / description / tools / model. Note that
# opencode-style keys (`mode`, `temperature`, nested tools+permission maps) are silently
# ignored here and are deliberately absent.
{
  den.aspects.applications.dev.ai.skills.gen-agents = {
    agent-extensions = {
      type = "skill";
      agents = {
        gen-scout = ./assets/gen-agents/gen-scout.md;
        gen-gate = ./assets/gen-agents/gen-gate.md;
        gen-spec = ./assets/gen-agents/gen-spec.md;
        gen-build = ./assets/gen-agents/gen-build.md;
      };
    };
  };
}
