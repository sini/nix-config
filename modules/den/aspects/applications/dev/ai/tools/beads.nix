# beads: an AI-supervised issue tracker for coding agents. Its own aspect in the
# codebase-memory-mcp mold — every piece that makes the tracker work lives here
# and nowhere else: the binaries, the viewer, the Claude Code plugin, the tool
# permission, and the pinned workspace. It is skill/hook-based, not an MCP
# server, so it sits beside the other ai tool aspects rather than under mcp/.
#
# The tracker is br (github:Dicklesworthstone/beads_rust) — SQLite + JSONL,
# resolving its workspace from BEADS_DIR below. It replaced bd
# (github:gastownhall/beads, Dolt-backed) at the 2026-08-25 cutover; the
# migration record is docs/runbooks/beads-dolt-to-rust.md plus the tracker's
# own den-hoag-bamt bead. The upstream bd→br migration skill stays registered
# through the cutover tail and retires with the runbook's post-validation
# cleanup.
{
  den.aspects.applications.dev.ai.tools.beads = {
    homeManager =
      {
        config,
        pkgs,
        inputs',
        ...
      }:
      {
        home.packages = [
          # `br` comes from the numtide collection rather than beads_rust's own
          # flake: that flake pulls a fenix nightly toolchain and crane, and
          # ships no flake.lock.
          inputs'.llm-agents.packages.beads-rust
          inputs'.llm-agents.packages.beads-viewer
        ];

        programs.claude-code = {
          # Store-pinned marketplace: CC resolves the plugin from the nix store
          # (the beads-rust source holds .claude-plugin/marketplace.json), not
          # by fetching GitHub at runtime.
          marketplaces.beads-rust = inputs'.llm-agents.packages.beads-rust.src;

          # THE PLUGIN IS REGISTERED BUT NOT ENABLED, and the reason is its skill.
          # br's plugin is nothing but `.claude/skills/br/SKILL.md` (367 lines; no
          # commands, no hooks), and that file's "Critical Rules for Agents" table
          # states two rules this fleet has measured false:
          #
          #   "ALWAYS use --json"  — inverted. --json is for a PROGRAM consumer;
          #     the model gets text. Owner-ruled 2026-08-25.
          #   "--format toon for reduced tokens" — measured on this tracker, TOON is
          #     LARGER than JSON (ready: 1,444,234 B toon vs 1,439,726 B json;
          #     blocked: 324,714 vs 323,974) and ~30x larger than native text.
          #     TOON dedups repeated KEYS; a bead payload is dominated by free-text
          #     description VALUES, so there is nothing for it to dedup.
          #
          # A Critical-Rules table is the strongest guidance shape a skill has, so
          # this cannot be counter-argued from a hook — it is dropped instead. The
          # command reference it also carried is available on demand and better
          # scoped: `br robot-docs guide` is 52 lines and says "--json ... for
          # scripts", which is the correct boundary.
          settings.enabledPlugins."beads@beads-rust" = false;

          # Upstream's own migration guidance, registered as a plain skill rather
          # than via br's plugin — it lives at skills/ in the source tree, outside
          # the plugin's .claude/skills/, so it carries none of the colliding
          # `beads:` plugin surface.
          skills.bd-to-br-migration = "${inputs'.llm-agents.packages.beads-rust.src}/skills/bd-to-br-migration";

          # br's plugin ships skills with NO hooks directory at all, so nothing
          # fires on session start or compaction on its own. This is our hook,
          # in the codebase-memory-mcp mold: content we author, about THIS
          # fleet's tracker. Deliberately invariant — no counts, no
          # binary-specific flags.
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
                    --json; a command whose consumer is you gets text. THE REASON IS TOKEN ECONOMY,
                    not compression: `br ready --limit 0` is 45,540 bytes as text and 1,439,726 as
                    --json — 31x for identical information, because you find the structure yourself
                    and the braces buy nothing. That holds with every compression layer switched
                    off. Read bodies through the renderer (STATUS/br-cat.sh <id>... > file, then
                    Read the file): structured in, rendered out. Filter corpora IN THE SCRIPT — a
                    sweep that hands you the corpus to grep mentally is the one that reports clean
                    without having measured anything.

                    NOT AN ESCAPE HATCH: --format toon. It dedups repeated keys, and a bead
                    payload is nearly all free-text values, so it measures LARGER than --json
                    here. Native text is the small form by a factor of ~30. Check any claim
                    about this with `br <cmd> --format toon --stats`.

                    ALWAYS PASS --limit 0. The bare list/ready forms cap silently.
                    COMMAND REFERENCE, on demand: `br robot-docs guide` (52 lines).
                    BOOT
                  '';
                }
              ];
            }
          ];

          settings = {
            permissions.allow = [
              "Bash(br *)"
            ];

            # Without BEADS_DIR, `br` resolves its workspace from the CWD, so any
            # agent command that cd's elsewhere first — another repo in the same
            # ecosystem, a worktree — loses the tracker, and the body-edit idiom
            # (`br show > body.md`, append, write back) TRUNCATES THE FILE BEFORE
            # the resolution error, so the read fails silently into a clobber.
            # Pinning the directory removes the class; br has no `-C` flag at
            # all, so this variable is the whole mechanism (`--db` exists for
            # per-invocation overrides). Safe as a single global: this is the
            # tracker for every gen-* repo by ruling, and the only .beads
            # workspace in the tree. It lives beside the ADRs and specs it cites
            # rather than in den-hoag, which ADR-0002 freezes.
            env.BEADS_DIR = "${config.home.homeDirectory}/Documents/repos/sini/den-ag-design/.beads";
          };
        };
      };
  };
}
