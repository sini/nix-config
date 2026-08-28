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
    agent-extensions =
      { inputs', ... }:
      {
        type = "plugin";
        marketplace = {
          name = "beads-rust";
          src = inputs'.llm-agents.packages.beads-rust.src;
          pluginId = "beads@beads-rust";
          enabled = false;
        };
        skills = {
          beads = inputs'.llm-agents.packages.beads-rust.src;
        };
      };

    homeManager =
      {
        config,
        lib,
        pkgs,
        inputs',
        ...
      }:
      let
        beadsDir = "${config.home.homeDirectory}/Documents/repos/sini/den-ag-design/.beads";

        # THE TRACKER HAS NO AUTOMATIC HOST-TO-HOST SYNC, and two artefacts imply it
        # does: `.beads/hooks/*` (bd's, gated on a `bd` binary that is no longer
        # installed, and never installed anyway — `core.hooksPath` is `.git/hooks`)
        # and `sync.remote` in config.yaml. `br sync` states the truth in its own
        # help: "br sync NEVER executes git commands or auto-commits".
        #
        # The real channel is .beads/issues.jsonl through git, and only ONE of its
        # four legs was unguarded. Outbound flush: handoff-gate.sh refuses on
        # dirty_count > 0. Outbound push: the ccstatusline `bd`/ahead-behind segments
        # show it. Inbound import: SELF-HEALING, br auto-imports on its next command
        # after a pull. THE PULL ITSELF had nothing behind it — measured 2026-08-27,
        # cortex sat 205 commits behind with no instrument saying so, which is this
        # project's whole defect class wearing a tracker costume. This is that
        # instrument.
        trackerDrift = pkgs.writeShellApplication {
          name = "beads-tracker-drift";
          runtimeInputs = [
            pkgs.git
            pkgs.coreutils
          ];
          text = ''
            r=$(dirname "''${BEADS_DIR:-${beadsDir}}")

            if ! git -C "$r" rev-parse --git-dir > /dev/null 2>&1; then
              echo "TRACKER: $r is not a git checkout — drift NOT checked."
              exit 0
            fi

            u=$(git -C "$r" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
            if [ -z "$u" ]; then
              echo "TRACKER: no upstream for $(git -C "$r" branch --show-current) — drift NOT checked."
              exit 0
            fi

            # The only network call, and it is bounded: a session must never block on
            # it. ★ A FAILED FETCH IS SAID SO, never folded into "in sync" — without
            # the fetch the counts run against a stale remote ref, and a clone 205
            # commits behind reads CLEAN. That is the exact miss this hook exists for,
            # so the failure mode must not reproduce it.
            stale=""
            if ! timeout 15 git -C "$r" fetch --quiet 2>/dev/null; then
              stale=" [fetch FAILED — counted against a STALE remote ref]"
            fi

            behind=$(git -C "$r" rev-list --count "HEAD..$u" 2>/dev/null || true)
            ahead=$(git -C "$r" rev-list --count "$u..HEAD" 2>/dev/null || true)

            # Checked one at a time: concatenating first would let an EMPTY behind
            # beside a "0" ahead read as the single digit 0 and pass as clean.
            for v in "$behind" "$ahead"; do
              case "$v" in
                "" | *[!0-9]*)
                  echo "TRACKER: rev-list failed — drift NOT checked.$stale"
                  exit 0
                  ;;
              esac
            done

            if [ "$behind" -gt 0 ]; then
              echo "TRACKER IS $behind COMMIT(S) BEHIND $u.$stale"
              echo "  git -C $r pull --ff-only   — br then auto-imports the JSONL on its next command."
              if [ "$ahead" -gt 0 ]; then
                echo "  DIVERGED: also $ahead unpushed. Do not --ff-only over local work; reconcile first."
              fi
            elif [ "$ahead" -gt 0 ]; then
              echo "TRACKER: $ahead unpushed commit(s) on $(git -C "$r" branch --show-current).$stale"
            else
              # Printed even when clean, on purpose: this line's ABSENCE then means the
              # hook did not run, rather than meaning there was nothing to say.
              echo "TRACKER: in sync with $u.$stale"
            fi
          '';
        };
      in
      {
        home.packages = [
          # `br` comes from the numtide collection rather than beads_rust's own
          # flake: that flake pulls a fenix nightly toolchain and crane, and
          # ships no flake.lock.
          inputs'.llm-agents.packages.beads-rust
          inputs'.llm-agents.packages.beads-viewer
        ];

        programs.claude-code = {

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
          # SessionStart only — NOT CwdChanged, which fires on every directory change
          # and would put a network fetch behind each one. `|| true` so a drift check
          # never blocks a session.
          settings.hooks.SessionStart = [
            {
              hooks = [
                {
                  type = "command";
                  command = "${lib.getExe trackerDrift} || true";
                }
              ];
            }
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
            env.BEADS_DIR = beadsDir;
          };
        };
      };
  };
}
