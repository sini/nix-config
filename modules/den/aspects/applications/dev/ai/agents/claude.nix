# claude-code config: a read-only declarative settings.json (seeded from cortex's
# canonical ~/.claude/settings.json) and the four-bucket ~/.claude state map that
# replaces the old blanket `persistHome [".claude"]`.
#
# The buckets:
#   - replicated (replicate.nix): memory + projects — Syncthing-synced AND
#     persisted below (stable storage so a home wipe doesn't re-pull from peers).
#   - generated (here): settings.json — a nix store symlink, identical on every
#     host. CC cannot mutate it at runtime; change config HERE, not in the TUI.
#   - persistHome: mutable local state worth keeping across a home wipe (/persist).
#   - cacheHome: regenerable scratch (/cache, separate dataset, not backed up).
#
# Switching blanket -> per-entry reuses the same /persist/.../.claude/* paths, so
# existing data is preserved; an entry omitted from every bucket is not deleted,
# only unmounted (recoverable by adding it to a bucket).
{ inputs, ... }:
{
  # Claude Code plugin marketplaces, store-pinned: CC resolves plugins from these
  # nix-store paths instead of fetching from GitHub at runtime (consistent with the
  # read-only settings.json below). Plugin *enablement* lives in settings.enabledPlugins.
  flake-file.inputs = {
    # The built-in official marketplace, store-pinned. CC otherwise bootstraps it
    # from github on launch and network-refreshes its timestamp, rewriting
    # known_marketplaces.json every session (the source of the .hm-backup clobber
    # loop). Registering it as a directory source pre-empts the bootstrap: local
    # sources are never refreshed, so the file stops diverging.
    claude-plugins-official = {
      url = "github:anthropics/claude-plugins-official";
      flake = false;
    };
  };

  den.aspects.applications.dev.ai.agents.claude = {
    homeLinux =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.socat
          pkgs.bubblewrap
        ];
      };

    homeManager =
      {
        agent-extensions,
        config,
        inputs',
        lib,
        pkgs,
        ...
      }:
      let
        extensionsList = lib.flatten agent-extensions;

        skillExts = lib.filter (e: e.type or "" == "skill" || e.type or "" == "mcp") extensionsList;
        mcpExts = lib.filter (e: e.type or "" == "mcp") extensionsList;
        pluginExts = lib.filter (e: e.type or "" == "plugin") extensionsList;

        claudeSkills = lib.foldl' (
          acc: e: if (e ? skills) then acc // (lib.mapAttrs (_: src: src.outPath or src) e.skills) else acc
        ) { } skillExts;

        claudeAgents = lib.foldl' (
          acc: e: if (e ? agents) then acc // e.agents else acc
        ) { } extensionsList;

        claudeCommands = lib.foldl' (
          acc: e: if (e ? commands) then acc // e.commands else acc
        ) { } extensionsList;

        # Two transports. A server declaring `url` is remote — claude-code
        # connects over HTTP and there is no process to spawn, so `command` is
        # absent and forcing type=stdio onto it produces an entry the client
        # cannot use. Everything else is a local process. Keyed on `url` rather
        # than an explicit flag so existing stdio aspects need no change.
        claudeMcpServers = lib.foldl' (
          acc: e:
          acc
          // (lib.mapAttrs (
            _name: server:
            if server ? url then
              {
                type = server.type or "http";
                inherit (server) url;
              }
              // lib.optionalAttrs (server ? headers) { inherit (server) headers; }
            else
              {
                type = "stdio";
                inherit (server) command;
                args = server.args or [ ];
                env = server.env or { };
              }
          ) (e.mcpServers or { }))
        ) { } mcpExts;

        claudeMarketplaces = lib.foldl' (
          acc: e: acc // { ${e.marketplace.name} = e.marketplace.src; }
        ) { } pluginExts;

        claudeEnabledPlugins = lib.foldl' (
          acc: e: acc // { ${e.marketplace.pluginId} = e.marketplace.enabled or true; }
        ) { } pluginExts;
      in
      {
        home.packages = [
          inputs'.llm-agents.packages.crush
          pkgs.nodejs_22
          # pkgs.markitdown
        ];

        # Don't track ~/.claude in any repo.
        programs.git.ignores = [
          ".claude"
        ];

        programs.claude-code = {
          enable = true;
          package = inputs'.llm-agents.packages.claude-code;
          enableMcpIntegration = true;
          mcpServers = claudeMcpServers;
          skills = claudeSkills;
          agents = claudeAgents;
          commands = claudeCommands;

          lspServers.nix = {
            command = lib.getExe pkgs.nil;
            extensionToLanguage.".nix" = "nix";
          };

          marketplaces = {
            claude-plugins-official = inputs.claude-plugins-official;
          }
          // claudeMarketplaces;

          settings = {
            theme = "auto";
            verbose = true;
            effortLevel = "xhigh";
            remoteControlAtStartup = false;
            includeCoAuthoredBy = false;
            gitAttribution = false;
            attribution = {
              commit = "";
              pr = "";
            };

            #autoMemoryEnabled = false; # I copied this from someones config, need to figure out what their memory looks like...
            autoMemoryDirectory = "~/.claude/memory";

            teammateMode = "in-process";

            permissions = {
              allow = [
                # Edit(**) covers Write/MultiEdit/NotebookEdit; Read(**) covers Grep/Glob
                "Read(**)"
                "Edit(**)"
                "Grep(**)"
                "LS(**)"
                "WebSearch"
                "TodoRead(**)"
                "TodoWrite(**)"
                "Task(**)"

                # git (read-only)
                "Bash(git status *)"
                "Bash(git diff *)"
                "Bash(git log *)"
                "Bash(git show *)"
                "Bash(git blame *)"
                "Bash(git rev-parse *)"
                "Bash(git remote *)"
                "Bash(git branch:*)"

                # git (write). Subagents cannot establish user intent from a teammate
                # message, so these previously round-tripped through the orchestrator.
                # Push stays the literal `origin main` form — no wildcard remote or ref,
                # so a force-push or a push to another branch still prompts.
                "Bash(git push origin main)"
                "Bash(git fetch *)"
                "Bash(git add *)"
                "Bash(git commit *)"
                "Bash(git stash *)"

                # gates
                "Bash(treefmt *)"
                "Bash(just *)"

                # nix
                "Bash(nix eval *)"
                "Bash(nix flake *)"
                "Bash(nix build *)"
                "Bash(nix fmt)"
                "Bash(nix develop *)"

                # Read-only file operations
                "Bash(ls:*)"
                "Bash(cat:*)"
                "Bash(head:*)"
                "Bash(tail:*)"
                "Bash(grep:*)"
                "Bash(rg:*)"
                "Bash(fd:*)"
                "Bash(find:*)"
                "Bash(which:*)"
                "Bash(pwd)"
                "Bash(whoami)"
                "Bash(uname:*)"
                "Bash(wc *)"

                # view / search
                "Bash(rg *)"
                "Bash(jq *)"
                "Bash(yq *)"
                "Bash(sort *)"
                "Bash(journalctl *)"
              ];

              deny = [ ];
            };

            env = {
              CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";

              # The one supported way to give Bash tool shells a per-directory environment.
              # Measured in claude-code 2.1.229: the binary reads this path and prepends its
              # contents to the shell it spawns —
              #   let n = Q.CLAUDE_ENV_FILE; if (n) { let i = readFile(n); if (i) r.push(i) }
              # The hooks below keep the snapshot current. Without it, agents inherit NOTHING from
              # a devshell: measured in a live session, a cwd with an allowed .envrc still gave
              # PRJ_ROOT/IN_NIX_SHELL/DIRENV_DIR all unset, so every dispatch had to hand-carry
              # `bd -C` and absolute tool paths in prompt text.
              CLAUDE_ENV_FILE = "${config.home.homeDirectory}/.claude/direnv-snapshot.sh";
              ENABLE_TOOL_SEARCH = "auto:5";

              # DISABLE_TELEMETRY also disables the GrowthBook feature-gate client,
              # and gate lookups short-circuit to their compiled-in default *before*
              # consulting the on-disk cache in ~/.claude.json. Several user-visible
              # features default to off and are gate-enabled, so telemetry-off silently
              # removes them (e.g. `tengu_ccr_bridge` gates the whole Remote Control
              # surface: /remote-control, `claude remote-control`, --rc, the settings
              # toggle). This flag is upstream's supported opt-out: keep telemetry off,
              # but let gate reads fall back to the cached payload. Note the cache no
              # longer refreshes while telemetry is off, so gate values are frozen at
              # whatever was last fetched — hence ~/.claude.json is persisted below.
              # CLAUDE_CODE_GB_DISK_CACHE_WHEN_TELEMETRY_OFF = "1";
            };

            enabledPlugins = {
              # All marketplaces (including claude-plugins-official) are store-pinned
              # via the marketplaces attr above, so plugins resolve from nix-store
              # paths and CC never network-fetches or rewrites known_marketplaces.json.
              "commit-commands@claude-plugins-official" = true;
              "skill-creator@claude-plugins-official" = true;
              "code-simplifier@claude-plugins-official" = true;
              "rust-analyzer-lsp@claude-plugins-official" = true;
            }
            // claudeEnabledPlugins;

            # Two events, deliberately: session start, and every directory change. NOT PreToolUse —
            # refreshing per tool call is the fork-bomb shape the upstream example warns about.
            # `|| true` so a direnv failure never blocks a session or a tool call.
            hooks = {
              SessionStart = [
                {
                  hooks = [
                    {
                      type = "command";
                      command = "bash ${config.home.homeDirectory}/.claude/load-direnv.sh || true";
                    }
                  ];
                }
                {
                  hooks = [
                    {
                      type = "command";
                      command = "bash ${config.home.homeDirectory}/.claude/budget.sh SessionStart || true";
                    }
                  ];
                }
              ];
              CwdChanged = [
                {
                  hooks = [
                    {
                      type = "command";
                      command = "bash ${config.home.homeDirectory}/.claude/load-direnv.sh || true";
                    }
                  ];
                }
              ];

              # A subagent finished. Measured failure this addresses: agents go idle WITHOUT
              # delivering their report — the notification arrives and the findings do not — and
              # the reflex is to re-prompt, which costs a round-trip on work that is already done.
              # Worse, an attempt that FAILED and wrote nothing is indistinguishable from work
              # never started when seen from outside. This makes the stop visible and names the
              # correct next move.
              SubagentStop = [
                {
                  hooks = [
                    {
                      type = "command";
                      command = "bash ${config.home.homeDirectory}/.claude/subagent-stop.sh || true";
                    }
                  ];
                }
                # ★ THE budget.sh SubagentStop CALL IS RETIRED — measured 2026-09-01 to deliver
                # NOTHING to the model in any output shape (see the PreToolUse block below).
                # It is not moved here but replaced there, because a budget reading is only
                # actionable BEFORE a dispatch, not after one ends.
                # ★★ subagent-stop.sh ABOVE IS ON THE SAME DEAD CHANNEL and is deliberately
                # left wired: it still writes its log, which is what proved the firing. Its
                # tree-first text has never reached a model and needs a live beat — the
                # natural one is PreToolUse/Agent, since "never re-dispatch, read the tree
                # first" is actionable exactly when the next dispatch is about to happen.
                # Carried as its own change rather than folded in here.
              ];

              # ★★ THE DISPATCH GATE MOVED TO PreToolUse/Agent, MEASURED 2026-09-01. It was on
              # SubagentStart, whose output NEVER REACHED THE MODEL — and neither did
              # SubagentStop's. Armed probe over 10 firings: a SubagentStop hook emitting
              # `systemMessage` and `hookSpecificOutput.additionalContext` produced ZERO
              # attachment records (live control, SessionStart => 7; the hook's own logfile
              # proves it FIRED every time). The failure was silent for the whole life of the
              # wiring: a budget line was computed correctly and delivered to nobody.
              # PreToolUse/Agent is strictly better than SubagentStart even setting delivery
              # aside — it fires BEFORE the dispatch rather than after it starts, which is
              # where a "no new dispatch" gate has to bite to prevent anything.
              PreToolUse = [
                {
                  matcher = "Agent";
                  hooks = [
                    {
                      type = "command";
                      command = "bash ${config.home.homeDirectory}/.claude/budget.sh PreToolUse || true";
                    }
                  ];
                }
              ];

              # ★★★ PostToolUse/Agent WAS WIRED HERE 2026-09-01 AND IS WITHDRAWN THE SAME DAY,
              # ON TWO INDEPENDENT GROUNDS. Recorded rather than deleted, because the reasoning
              # is what stops it being re-proposed.
              # THE PROBLEM IT AIMED AT IS REAL: PreToolUse reports at DISPATCH, which is right
              # for the GATE ("no new dispatch" must bite before a dispatch) but is not when the
              # orchestrator CHOOSES. That moment is when an agent RETURNS, and there the reading
              # was absent, so it got INFERRED — measured that day: several turns asserted
              # "ctx ~70%, near the no-dispatch line" and self-throttled while the next real
              # reading was 52%, and closeout was entered at 59.7%.
              # ★ GROUND 1 — WRONG BEAT, BY CONSTRUCTION. The Agent tool RETURNS AT SPAWN
              # ("Spawned successfully … the agent is now running"), so PostToolUse/Agent fires
              # microseconds after PreToolUse at the SAME beat. It duplicates the dispatch
              # reading and never observes a completion, however well it delivers.
              # ★ GROUND 2 — NO HOOK IS NEEDED. `budget.sh` READS ON DEMAND:
              #     printf '{"transcript_path":"<session>.jsonl"}' | bash ~/.claude/budget.sh manual
              #     ⇒ BUDGET manual · ctx 64.0% · 5h 29.0% (86m) · 7d 22.0%    (measured)
              # Without the payload `ctx` degrades to `?` and the 5h/7d arms still read, so the
              # transcript path is what the ctx arm needs. A command the model can run at any
              # beat strictly dominates a hook that fires at one beat and must be verified.
              # ⇒ THE COMPLETION BEAT HAS NO LIVE HOOK CHANNEL and does not need one:
              # SubagentStop is measured dead, TeammateIdle is a strict subset of it (see below),
              # and the on-demand read covers every beat including those two.

              # TeammateIdle is DELIBERATELY NOT WIRED. It fires (measured: claude-code
              # 2.1.246, coincident with SubagentStop to the same second across 5 dispatches),
              # but its payload is a strict SUBSET: it carries teammate_name and team_name,
              # which duplicate SubagentStop's agent_type and session_id, and lacks agent_id,
              # agent_transcript_path, last_assistant_message and background_tasks. Same
              # moment, less data — so wiring it would only duplicate the firing.

              # About to compact. Standing law here: markdown does not survive compaction, the
              # graph does. This runs the close-protocol reads and puts their ANSWERS in context,
              # so the checkpoint decision is made against measured state rather than recall.
              PreCompact = [
                {
                  hooks = [
                    {
                      type = "command";
                      command = "bash ${config.home.homeDirectory}/.claude/pre-compact.sh || true";
                    }
                  ];
                }
              ];
            };
          };
        };

        # RETIRED: `.claude/env.sh` used to live here, on the belief that Claude Code sources it.
        # It does not. Measured against claude-code 2.1.229: `env.sh` occurs ZERO times in the
        # binary, with live controls in the same run (`settings.json` 201, `CLAUDE.md` 201,
        # `.claude` 2933). It never ran. The supported mechanism is CLAUDE_ENV_FILE above.
        # SubagentStop: make a silent idle visible, and name the correct next move.
        # Does not try to decide whether a report arrived. It records the stop and states the
        # rule, which is what the orchestrator actually gets wrong under pressure.
        #
        # ★ THE STATED REASON FOR THAT WAS "the hook cannot see the conversation" AND IT IS
        # FALSE (measured 2026-08-31): the SubagentStop payload carries
        # `last_assistant_message`, present with correct content in 3 of 3 captures, plus
        # `agent_transcript_path` to the subagent's own transcript. The hook COULD tell a
        # delivered report from a silent idle mechanically rather than instructing the reader
        # to go and check — the discipline-to-mechanism move handoff-gate.sh already made.
        # The conclusion (state the rule, don't adjudicate) is LEFT STANDING; only its basis
        # is corrected. Making it report-aware changes what it says to the orchestrator and
        # is an owner call, not a comment fix.
        home.file.".claude/subagent-stop.sh" = {
          executable = true;
          text = ''
            #!/usr/bin/env bash
            set -uo pipefail
            log="$HOME/.claude/subagent-stops.log"
            mkdir -p "$(dirname "$log")"
            printf '%s\tstopped\n' "$(date -Is)" >> "$log" 2>/dev/null || true
            cat <<'"'"'MSG'"'"'
            A subagent just STOPPED.

            If its report has NOT arrived: TREE FIRST, then prompt ONCE. Never re-dispatch — a
            resend duplicates completed work, while a message revives the agent with its context.
            Read the artefact it was told to write before assuming nothing happened: reports
            routinely cross the idle notification.

            A silent idle is NOT a clean result. Never infer a finding, a pass, or an absence from
            a report that never arrived — say it is outstanding.

            An attempt that failed and wrote NOTHING looks identical from here to work never
            started. If the tree is unchanged, that is "no artefact", never "no attempt".
            MSG
            exit 0
          '';
        };

        # ONE LEAN BUDGET LINE per firing. It reports STATE and the tripped gate; it does
        # NOT restate the rules. The rules live in den-ag-design STATUS/RESUME-PROMPT-ARCH.md
        # and are read once at boot — a policy repeated on every firing is a second copy that
        # decays, and 400 identical repetitions train the reader to skip the line that finally
        # differs.
        #
        # Field availability, measured (claude-code 2.1.246, payload capture 2026-08-31):
        #   SessionStart  : session_id transcript_path cwd model source [prompt_id]
        #   SubagentStart : session_id transcript_path cwd agent_id agent_type prompt_id
        #   SubagentStop  : the above + agent_transcript_path last_assistant_message
        #                   background_tasks effort stop_hook_active permission_mode
        # `model` reaches ONLY SessionStart, which is why the divisor below cannot come from
        # the payload on the events that need it most.
        home.file.".claude/budget.sh" = {
          executable = true;
          text = ''
            #!/usr/bin/env bash
            set -uo pipefail
            sub="$HOME/.headroom/subscription_state.json"
            event="''${1:-unknown}"

            # ★★★ FIRING LOG — this is what separates "the hook NEVER FIRED" from "the hook
            # FIRED AND REACHED NOBODY", and those are different defects with different fixes.
            # The second is the silent one: SubagentStop fired correctly on every one of ten
            # probe dispatches and delivered ZERO, and only its own logfile proved the
            # difference. Without a line like this a delivery count of 0 is UNDECIDABLE, and
            # an undecidable zero reads as a dead channel. One append per hook invocation.
            printf '%s\t%s\n' "$(date -Is)" "$event" \
              >> "$HOME/.claude/budget-fires.log" 2>/dev/null || true

            payload=""
            if [ ! -t 0 ]; then payload="$(cat 2>/dev/null || true)"; fi
            transcript=$(printf '%s' "$payload" | jq -r '.transcript_path // empty' 2>/dev/null)

            # ★ DIVISOR DEFAULTS TO 1,000,000 (owner-ruled 2026-08-31): every orchestrator is
            # Opus or Fable, and transcript_path is always the ORCHESTRATOR's window, never a
            # subagent's. This is what makes a model cache unnecessary on the events that
            # carry no model. It fails toward UNDER-reporting, so an orchestrator on a 200K
            # model would read 5x low and reach compaction rather than raise a false alarm.
            # ★ NEVER TAKE THE MODEL FROM THE TRANSCRIPT. It records `claude-opus-5` with the
            # `[1m]` marker STRIPPED (measured: 218/218 assistant messages) while the
            # SessionStart payload records `claude-opus-5[1m]`. Trusting it selects a 200000
            # divisor and reports 133% where the truth is 26.6% — tripping every gate at once.
            limit=1000000
            model=$(printf '%s' "$payload" \
              | jq -r 'if (.model|type)=="string" then .model else (.model.id // empty) end' 2>/dev/null)
            case "$model" in
              "" | *"[1m]") ;;
              claude-haiku-* | claude-sonnet-5) limit=200000 ;;
            esac

            ctx="?"
            if [ -n "$transcript" ] && [ -s "$transcript" ]; then
              tok=$(jq -r 'select(.type=="assistant") | select(.isSidechain != true)
                           | select(.message.usage != null) | .message.usage
                           | (.input_tokens//0)+(.cache_read_input_tokens//0)+(.cache_creation_input_tokens//0)' \
                      "$transcript" 2>/dev/null | tail -1)
              case "''${tok:-}" in
                "" | *[!0-9]*) ctx="?" ;;
                *) ctx=$(awk -v t="$tok" -v l="$limit" 'BEGIN{printf "%.1f", t*100/l}') ;;
              esac
            fi

            # utilization_pct ONLY: `used` and `limit` read 0 against a live percentage, so
            # any limit-minus-used arithmetic reports a full window as exhausted.
            five="?"; seven="?"; mins="?"; stale=""
            if [ -s "$sub" ]; then
              vals=$(jq -r '[(.latest.five_hour.utilization_pct // "x"),
                             (.latest.seven_day.utilization_pct // "x"),
                             (.latest.five_hour.seconds_to_reset // 0)] | @tsv' "$sub" 2>/dev/null)
              five=$(printf '%s' "$vals" | cut -f1)
              seven=$(printf '%s' "$vals" | cut -f2)
              secs=$(printf '%s' "$vals" | cut -f3)
              case "$five$seven" in "" | *[!0-9.]*) five="?"; seven="?" ;; esac
              mins=$(awk -v s="''${secs:-0}" 'BEGIN{ if (s+0>0) printf "%d", s/60; else printf "?" }')
              # The poller runs a measured ~17% error rate, so staleness is a state to name.
              age=$(( $(date +%s) - $(stat -c %Y "$sub" 2>/dev/null || echo 0) ))
              [ "$age" -gt 900 ] && stale=" STALE(''${age}s)"
            fi

            # Thresholds are HERE because a hook has to decide; the rules they serve are in
            # the bootstrap prompt. WEEKLY OUTRANKS CONTEXT: a session limit resumes cleanly,
            # a weekly limit needs handoff and recovery, so it is evaluated last and wins.
            #
            # ★ EACH GATE NAMES ITS CONSTRAINT, NEVER A MOOD (HANDOFF-RULES.md rule 4:
            # "vigilance is a procedure, not a mood"). The two closeout gates are DIFFERENT
            # KINDS OF EVENT and must not read alike: ctx>=90 has a real deadline, because the
            # window only shrinks and compaction is the cliff. 7d>=95 has none — 5% is hours
            # of light single-agent work, or under an hour at 4x parallel Opus. Wording it as
            # an emergency buys a rushed handoff in the one case where recovery is expensive
            # and handoff QUALITY is the whole point.
            gate=""
            if [ "$ctx" != "?" ]; then
              gate=$(awk -v c="$ctx" 'BEGIN{
                if (c+0 >= 90)      print "CLOSE OUT (ctx>=90) - compaction is the deadline";
                else if (c+0 >= 85) print "PREPARE CLOSEOUT (ctx>=85)";
                else if (c+0 >= 70) print "NO NEW DISPATCH (ctx>=70) - in-flight only";
              }')
            fi
            if [ "$seven" != "?" ] && awk -v w="$seven" 'BEGIN{exit !(w+0>=95)}'; then
              gate="CLEAN CLOSEOUT (7d>=95) - unhurried; finish in-flight, no new dispatch"
            fi

            line=$(printf 'BUDGET %s · ctx %s%% · 5h %s%% (%sm) · 7d %s%%%s%s' \
              "$event" "$ctx" "$five" "$mins" "$seven" "$stale" "''${gate:+ · GATE: $gate}")

            # ★ DELIVERY DIFFERS BY EVENT, MEASURED 2026-09-01 (claude-code 2.1.246), and
            # plain stdout reaches the model on SessionStart ONLY. Armed probe, 10 fires:
            # a SubagentStop hook emitting `systemMessage` AND
            # `hookSpecificOutput.additionalContext` produced ZERO deliveries — the event
            # has no attachment record at all (control: SessionStart => 7). The same
            # `additionalContext` shape on PreToolUse DID land. So this is not a schema
            # problem on SubagentStop; that event cannot reach the model in any shape.
            # ★ THE `hookSpecificOutput` ARM STAYS GENERALISED over event name rather than
            # hardcoding PreToolUse: the shape is what the event family accepts, and threading
            # `$event` costs nothing while letting a future wiring reuse it without editing the
            # emitter. PostToolUse is NOT wired (see the hooks block: wrong beat, and the
            # on-demand read supersedes it) — this arm simply does not refuse it.
            # ★★ WHEN A DELIVERY COUNT IS 0, IT IS UNDECIDABLE UNTIL THE FIRING LOG IS READ.
            # `~/.claude/budget-fires.log` gets one append per invocation, so "never fired" and
            # "fired and reached nobody" are distinguishable — the distinction SubagentStop's
            # ten-fire probe needed its own logfile to make. Count deliveries as records of
            # type "attachment" in the session transcript, NEVER as a raw grep: the event name
            # appears in this file and in any tool call that installs a probe.
            case "$event" in
              PreToolUse* | PostToolUse*)
                printf '%s' "$line" \
                  | jq -Rs --arg ev "$event" '{hookSpecificOutput:{hookEventName:$ev,additionalContext:.}}'
                ;;
              *) printf '%s\n' "$line" ;;
            esac
            exit 0
          '';
        };

        # PreCompact: run the close-protocol reads and put their ANSWERS in context.
        # Every command here is a read. It changes nothing.
        home.file.".claude/pre-compact.sh" = {
          executable = true;
          text = ''
            #!/usr/bin/env bash
            set -uo pipefail
            echo "COMPACTION CHECKPOINT — measured state, not recall:"
            if command -v br >/dev/null 2>&1; then
              n=$(br list --status in_progress --limit 0 2>/dev/null | grep -c "" || echo "?")
              echo "  in_progress rows      : $n   (a status nobody stands behind is a claim with no writer)"
              br sync --status 2>/dev/null | grep -i dirty | sed "s/^/  export /" || true
            else
              echo "  tracker               : br not on PATH here"
            fi
            for r in "$HOME"/Documents/repos/sini/den-ag-design "$HOME"/Documents/repos/sini/gen*; do
              [ -d "$r/.git" ] || continue
              st=$(git -C "$r" status --porcelain 2>/dev/null | wc -l)
              ah=$(git -C "$r" rev-list --count @{u}..HEAD 2>/dev/null || echo 0)
              [ "$st" -gt 0 ] || [ "$ah" -gt 0 ] && printf "  %-22s %s modified, %s unpushed\n" "$(basename "$r")" "$st" "$ah"
            done
            cat <<'"'"'MSG'"'"'

            Before context is lost: EVERY LIVE OBLIGATION GOES IN A BEAD BODY. Markdown does not
            survive compaction; the graph does. Bank rulings, forks and residue at their carrier
            NOW — not in the handoff alone, which is wholesale-replaced.
            MSG
            exit 0
          '';
        };

        home.file.".claude/load-direnv.sh" = {
          executable = true;
          text = ''
            #!/usr/bin/env bash
            # Refresh the CLAUDE_ENV_FILE snapshot from direnv for the CURRENT directory.
            #
            # ★ THE HAZARD THIS SHAPE AVOIDS: evaluating direnv on every shell fork-bombs the host,
            # and an agent asked to fix it re-triggers the same loop. So this runs on exactly TWO
            # hook events — session start and directory change — and writes a SNAPSHOT the harness
            # then reads per shell. It never evaluates during a Bash call.
            set -uo pipefail
            snap="''${CLAUDE_ENV_FILE:-$HOME/.claude/direnv-snapshot.sh}"
            mkdir -p "$(dirname "$snap")"
            # No .envrc here: leave whatever the last directory established rather than blanking it,
            # so moving into an unmanaged directory does not strip the tools mid-task.
            [ -e .envrc ] || exit 0
            command -v direnv >/dev/null || exit 0
            tmp="$(mktemp)"
            if direnv export bash 2>/dev/null > "$tmp"; then
              # Write via temp+mv: a half-written snapshot is sourced by every later shell, so a
              # partial write is worse than a stale one.
              mv "$tmp" "$snap"
            else
              rm -f "$tmp"
            fi
            exit 0
          '';
        };
      };

    # Mutable local state — survives a home wipe, in /persist, NOT synced.
    # memory + projects are replicated (replicate.nix); they live here too so a
    # wipe doesn't force Syncthing to re-pull the whole set from peers.
    persistHome = {
      directories = [
        ".claude/memory"
        ".claude/projects"
        ".claude/plugins"
        ".claude/file-history"
        ".claude/tasks"
        ".claude/todos"
        ".claude/teams"
        ".claude/workflows"
        ".claude/backups"
        ".claude/sessions"
        ".claude/jobs"
      ];
      files = [
        ".claude/.credentials.json"
        ".claude/history.jsonl"
        # Not under .claude/ — CC's main state file: per-project history, MCP server
        # approvals, onboarding state, and the cached GrowthBook feature payload the
        # env flag above falls back to. With telemetry off that payload is never
        # refetched, so losing this file permanently disables every gated feature.
        ".claude.json"
      ];
    };

    # Regenerable scratch — /cache dataset, not backed up. Lost-on-wipe is fine.
    cacheHome = {
      directories = [
        ".claude/cache"
        ".claude/paste-cache"
        ".claude/session-env"
        ".claude/shell-snapshots"
        ".claude/statsig"
        ".claude/debug"
        ".claude/daemon"
        ".claude/ide"
      ];
      files = [
        ".claude/stats-cache.json"
        ".claude/mcp-needs-auth-cache.json"
        ".claude/.last-cleanup"
        ".claude/daemon.log"
      ];
    };

    replicateHome.directories = [
      ".claude/memory"
      ".claude/projects"
    ];
  };
}
