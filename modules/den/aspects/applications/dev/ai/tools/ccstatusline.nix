# ccstatusline (github:sirmalloc/ccstatusline): the Claude Code status line, taken
# from the numtide collection we already ship as an input rather than from npx at
# runtime. Its own aspect in the beads.nix/rtk.nix mold — the binary, the config,
# the Claude Code wiring and the one workflow-specific segment all live here.
#
# ★ THE CONFIG IS A READ-ONLY STORE SYMLINK, like ~/.claude/settings.json. Its own
# TUI (`ccstatusline` with no args) is still the right way to BROWSE widgets and
# preview colours, but its save will fail — change the layout HERE, not in the TUI.
# That is deliberate for a second reason: on save the TUI ALSO rewrites
# ~/.claude/settings.json to sync widget hooks, and that file is generated too.
#
# The custom `bd` segment is the reason this aspect exists rather than a two-line
# default. It surfaces, continuously, the exact state STATUS/handoff-gate.sh
# refuses a commit over — in-progress rows nobody closed, and a beads export that
# has gone stale behind a DB write — instead of discovering it at close.
{
  den.aspects.applications.dev.ai.tools.ccstatusline = {
    homeManager =
      {
        config,
        lib,
        pkgs,
        inputs',
        ...
      }:
      let
        # Single source of truth: the workspace pin lives in tools/beads.nix and is
        # read back here rather than restated. Empty when the beads aspect is not
        # opted in, in which case the segment falls through to whatever `br`
        # resolves from the cwd — and says so loudly if that resolves to nothing.
        beadsDir = lib.attrByPath [
          "programs"
          "claude-code"
          "settings"
          "env"
          "BEADS_DIR"
        ] "" config;

        beadsStatus = pkgs.writeShellApplication {
          name = "ccstatusline-beads";
          runtimeInputs = [
            inputs'.llm-agents.packages.beads-rust
            pkgs.jq
            pkgs.coreutils
          ];
          text = ''
            # ccstatusline re-runs every custom-command widget on EVERY render and
            # Claude Code renders sub-second, so these queries are CACHED, not
            # re-run: measured together they cost ~0.40s (ready 0.21, list 0.11,
            # sync 0.08) against a 1000ms per-widget timeout. Uncached this is a
            # permanent background process storm for a number that moves rarely.
            cache="''${XDG_RUNTIME_DIR:-/tmp}/ccstatusline-beads.$(id -u)"
            ttl=15

            if [ -f "$cache" ] && [ $(( $(date +%s) - $(stat -c %Y "$cache") )) -lt "$ttl" ]; then
              cat "$cache"
              exit 0
            fi

            export BEADS_DIR="''${BEADS_DIR:-${beadsDir}}"

            # br's three JSON commands return three DIFFERENT envelopes: `ready` is a
            # BARE ARRAY, `list` wraps as {issues,total,...}, `sync` is an object.

            # ★ EACH ACCESSOR ASSERTS ITS ENVELOPE and emits a non-number when the
            # shape is wrong, because a bare `.total` or `length` does not fail on a
            # wrong envelope — it ANSWERS. Measured while building this: `length`
            # against `{"issues":[]}` returns 1, its KEY COUNT, so a `ready` that
            # ever stopped being a bare array would read as one ready bead rather
            # than as a fault. `x` is unreachable as a count, so it lands in `broken`.
            ready=$(br ready --limit 0 --json 2>/dev/null \
              | jq -r 'if type == "array" then length else "x" end' 2>/dev/null || true)
            prog=$(br list --status in_progress --limit 0 --json 2>/dev/null \
              | jq -r 'if (.total | type) == "number" then .total else "x" end' 2>/dev/null || true)
            dirty=$(br sync --status --json 2>/dev/null \
              | jq -r 'if (.dirty_count | type) == "number" then .dirty_count else "x" end' 2>/dev/null || true)

            # A missing or broken `br` reaches here as an empty string, so the
            # `2>/dev/null` above cannot turn a dead instrument into a clean zero.
            # Anything that is not a plain number is a FAILURE.
            broken=0
            for v in "$ready" "$prog" "$dirty"; do
              case "$v" in
                "" | *[!0-9]*) broken=1 ;;
              esac
            done

            red=$'\033[31m'
            reset=$'\033[0m'

            if [ "$broken" -eq 1 ]; then
              out="''${red}bd ?''${reset}"
            else
              # The ready count prints EVEN AT ZERO. ccstatusline hides a segment
              # whose output is empty, so a segment that went quiet on success would
              # be indistinguishable from a segment whose tool died — and an absent
              # `bd` must always mean the instrument broke, never that the queue is
              # clean. `br ready` empty is itself a reportable state, not silence.
              out="bd $ready"
              if [ "$prog" -gt 0 ]; then out="$out +$prog"; fi
              if [ "$dirty" -gt 0 ]; then out="$out ''${red}!$dirty''${reset}"; fi
            fi

            # Sessions run concurrently and share this cache; write through a temp
            # so a reader never sees a half-written line.
            tmp=$(mktemp "$cache.XXXXXX")
            printf '%s' "$out" > "$tmp"
            mv -f "$tmp" "$cache"
            printf '%s' "$out"
          '';
        };

        # `id` is required on every widget by ccstatusline's schema and carries no
        # meaning for a generated config, so it is derived from position rather than
        # hand-maintained. The TUI mints UUIDs; nothing reads them across saves that
        # we do not regenerate anyway.
        withIds = lib.imap0 (i: line: lib.imap0 (j: w: w // { id = "l${toString i}-${toString j}"; }) line);

        sep = {
          type = "separator";
          character = " · ";
          color = "brightBlack";
        };

        settings = {
          version = 3;

          lines = withIds [
            # Line 1 — WHERE YOU ARE and WHAT IS UNLANDED. Every widget here is one
            # the close protocol asks about: which worktree holds the writer, what
            # is uncommitted, what is committed but unpushed, what the tracker says.
            [
              {
                type = "current-working-dir";
                color = "cyan";
                # Drops the "cwd: " label; a path does not need naming.
                rawValue = true;
                # metadata is record(string,string) in the schema — booleans are
                # compared against the STRING "true", so `true` would read as unset.
                metadata.abbreviateHome = "true";
              }
              sep
              {
                type = "git-branch";
                color = "magenta";
                metadata.hideNoGit = "true";
              }
              {
                type = "git-changes";
                color = "yellow";
                metadata.hideNoGit = "true";
              }
              {
                # ↑n↓m against upstream: the "unpushed commits" half of the close
                # protocol, and the one a clean `git status` hides completely.
                # `hideNoGit` is deliberately NOT set here, unlike its neighbours:
                # in sync the widget returns null on its own, so the flag only ever
                # gates "(no git)" and "(no upstream)" — and a branch with no
                # upstream is the exact shape a fresh .worktrees/<task> takes, which
                # is where unpushed work strands.
                type = "git-ahead-behind";
                color = "brightRed";
              }
              {
                # Renders nothing outside a worktree, so it is a positive signal:
                # visible ⇒ you are in .worktrees/<task> and are its single writer.
                type = "worktree-name";
                color = "yellow";
              }
              { type = "flex-separator"; }
              {
                type = "custom-command";
                commandPath = lib.getExe beadsStatus;
                # The segment emits its own ANSI for the stale-export alarm, so it
                # must be exempt from colour stripping. maxWidth is deliberately
                # unset: truncation counts escape bytes as characters.
                preserveColors = true;
              }
            ]

            # Line 2 — WHAT IT COSTS. The agent cap is quota-driven and model-tiered,
            # so the weekly Opus figure is a scheduling input, not trivia.
            [
              {
                type = "model";
                color = "cyan";
                rawValue = true;
              }
              {
                type = "thinking-effort";
                color = "brightBlack";
              }
              sep
              {
                type = "context-percentage";
                color = "green";
              }
              sep
              {
                type = "session-cost";
                color = "brightYellow";
              }
              {
                type = "session-usage";
                color = "brightBlue";
              }
              {
                # ★ `weekly-usage`, NOT `weekly-opus-usage`. Measured 2026-08-28 against
                # the live account: weekly-usage 70.0%, weekly-opus-usage 0.0%,
                # weekly-sonnet-usage 0.0%. There is no per-model weekly cap for this
                # account, so both per-model widgets report a limit that does not exist
                # and read a permanent, plausible-looking zero. The original choice was
                # reasoning from OUR agent cap being model-tiered — but that is a quota
                # policy we invented, not a limit the API reports.
                type = "weekly-usage";
                color = "brightMagenta";
                # `slider` is the only display mode that earns its width: a 10-block bar
                # AND the number. Measured — `progress` is 46 chars, `slider-only` drops
                # the number, and full-data/icon-* are no-ops that render exactly like the
                # default. Two sliders side by side make the BINDING constraint legible
                # without reading either figure.
                metadata.display = "slider";
              }
              {
                # ★ Fable has a REAL per-model weekly cap where Opus and Sonnet do not,
                # and on 2026-08-28 it was the tighter one: Fable 88.0% against overall
                # 70.0%. Showing only the overall figure hides the limit that actually
                # binds first.
                type = "fable-weekly-usage";
                color = "brightRed";
                metadata.display = "slider";
              }
            ]
          ];

          flexMode = "full-minus-40";
          compactThreshold = 60;
          colorLevel = 2;
          defaultPadding = " ";
          inheritSeparatorColors = false;
          globalBold = false;
          gitCacheTtlSeconds = 5;
          minimalistMode = false;

          # Off on purpose: powerline separators are private-use codepoints that
          # render as tofu without a patched font, and the fallback is silent.
          powerline = {
            enabled = false;
            separators = [ "" ];
            separatorInvertBackground = [ false ];
            startCaps = [ ];
            endCaps = [ ];
            autoAlign = false;
            continueThemeAcrossLines = false;
          };
        };
      in
      {
        home.packages = [ inputs'.llm-agents.packages.ccstatusline ];

        # home.file, not xdg.configFile: ccstatusline joins homedir + ".config"
        # directly and never consults XDG_CONFIG_HOME, so this is the path it reads.
        home.file.".config/ccstatusline/settings.json".source =
          (pkgs.formats.json { }).generate "ccstatusline-settings.json"
            settings;

        programs.claude-code.settings.statusLine = {
          type = "command";
          command = lib.getExe inputs'.llm-agents.packages.ccstatusline;
          padding = 0;
        };
      };
  };
}
