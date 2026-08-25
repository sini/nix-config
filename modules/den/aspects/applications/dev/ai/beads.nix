# beads: an AI-supervised issue tracker for coding agents. Its own aspect in the
# codebase-memory-mcp mold — every piece that makes the tracker work lives here
# and nowhere else: the binaries, the viewer, the Claude Code plugin, the tool
# permission, and the pinned workspace. It is skill/hook-based, not an MCP
# server, so it sits beside the other ai tool aspects rather than under mcp/.
#
# Two implementations are installed side by side, and they do NOT conflict —
# different binaries (`bd` vs `br`), and both resolve the same workspace from
# BEADS_DIR below:
#   - bd  (github:gastownhall/beads) — Dolt-backed, the ACTIVE tracker.
#   - br  (github:Dicklesworthstone/beads_rust) — SQLite + JSONL, staged for the
#     cutover. Its binary and the upstream bd→br migration skill are available
#     now; its plugin stays OFF because upstream also names it `beads`, so the
#     two would collide in the `beads:` skill namespace. See the migration
#     runbook for the exact cutover hunks.
{ inputs, ... }:
{
  flake-file.inputs.beads = {
    url = "github:gastownhall/beads";
    inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  den.aspects.applications.dev.ai.beads = {
    homeManager =
      {
        config,
        pkgs,
        inputs',
        ...
      }:
      {
        home.packages = [
          # `bd` must be on PATH: the plugin's SessionStart/PreCompact hooks run
          # `bd prime`, and the slash commands shell out to it.
          inputs'.beads.packages.default
          # `br` — staged, see the header. Comes from the numtide collection
          # rather than beads_rust's own flake: that flake pulls a fenix nightly
          # toolchain and crane, and ships no flake.lock.
          inputs'.llm-agents.packages.beads-rust
          inputs'.llm-agents.packages.beads-viewer
        ];

        programs.claude-code = {
          # Store-pinned marketplace: CC resolves the plugin from the nix store
          # (inputs.beads = the flake source, which holds .claude-plugin/
          # marketplace.json), not by fetching GitHub at runtime.
          marketplaces.beads-marketplace = inputs.beads;
          settings.enabledPlugins."beads@beads-marketplace" = true;

          # Upstream's own migration guidance, registered as a plain skill rather
          # than via br's plugin — it lives at skills/ in the source tree, outside
          # the plugin's .claude/skills/, so it carries none of the colliding
          # `beads:` plugin surface.
          skills.bd-to-br-migration = "${inputs'.llm-agents.packages.beads-rust.src}/skills/bd-to-br-migration";

          # The bd plugin's SessionStart/PreCompact hooks run `bd prime`, which emits
          # generic protocol boilerplate — and br's plugin ships skills with NO hooks
          # directory at all, so nothing fires on compaction after the cutover. This is
          # the replacement, in the codebase-memory-mcp mold: content we author, about
          # THIS fleet's tracker. Deliberately invariant — no counts, no binary-specific
          # flags — so it survives the bd -> br swap untouched.
          settings.hooks.SessionStart = [
            {
              hooks = [
                {
                  type = "command";
                  command = pkgs.writeShellScript "beads-session-boot" ''
                    cat << 'BOOT'
                    Beads tracker — the workspace is pinned by BEADS_DIR, so it resolves from any cwd.

                    BOOT ORDER. Read both before touching the tracker; neither is optional:
                      1. STATUS/RESUME-PROMPT-ARCH.md   (in the BEADS_DIR checkout)
                      2. STATUS/HANDOFF.md — the session-state channel. It is WHOLESALE-REPLACED at
                         each close, so anything not deliberately re-carried is gone, and its
                         COMMISSION field outranks its recommendation field.

                    ARC STATE LIVES IN THE GRAPH. Derive every figure by query. Never quote a count
                    from a document — including this one.

                    NEVER PUT JSON IN THE MODEL'S LOOP. A command whose consumer is a program gets
                    --json; a command whose consumer is you gets text. Read bodies through the
                    renderer (STATUS/bd-cat.sh <id>... > file, then Read the file): structured in,
                    rendered out. A bare --json result is both dead tokens and the shape the
                    compression layer has the most leverage over, so a sweep over one can come back
                    looking clean without having measured anything. Filter corpora IN THE SCRIPT.

                    ALWAYS PASS --limit 0. The bare list/ready forms cap silently.
                    BOOT
                  '';
                }
              ];
            }
          ];

          settings = {
            permissions.allow = [
              "Bash(bd *)"
              "Bash(br *)"
            ];

            # `bd`/`br` resolve their workspace from the CWD, so any agent command
            # that cd's elsewhere first — another repo in the same ecosystem, a
            # worktree — loses the tracker. Two of its failure modes are loud, but
            # the body-edit idiom (`bd show > body.md`, append, write back)
            # TRUNCATES THE FILE BEFORE the resolution error, so the read fails
            # silently into a clobber. Pinning the directory removes the class
            # rather than asking every call site to remember `-C`. Safe as a single
            # global: this is the tracker for every gen-* repo by ruling, and the
            # only .beads workspace in the tree. It lives beside the ADRs and specs
            # it cites rather than in den-hoag, which ADR-0002 freezes. Both
            # implementations honour this same variable, so the cutover does not
            # move the workspace.
            env.BEADS_DIR = "${config.home.homeDirectory}/Documents/repos/sini/den-ag-design/.beads";
          };
        };
      };
  };
}
