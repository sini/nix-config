# OpenAI Codex CLI (github:openai/codex), from numtide/llm-agents: the same shared
# skills, subagents and MCP servers as claude/agy/opencode, folded off agent-extensions.
#
# config.toml is codex's own state file as well as ours: it writes project trust and hook
# trust into it at runtime. So it is NOT the module's store symlink — `programs.codex.settings`
# stays the declaration surface (other modules may set it too) and core.lens-files projects
# it into the mutable file on every activation.
{ den, ... }:
{
  den.aspects.applications.dev.ai.agents.codex = {
    includes = [ den.aspects.core.lens-files ];

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
        collect = key: lib.foldl' (acc: e: acc // (e.${key} or { })) { } extensionsList;

        skills = lib.mapAttrs (_: src: src.outPath or src) (collect "skills");

        # stdio: one argv split into command + args. url: remote, with a bearer token read
        # from its file at connect time by http_headers_helper, so it never enters the store.
        mcpServers =
          lib.mapAttrs
            (
              name: s:
              if s ? url then
                {
                  inherit (s) url;
                }
                // lib.optionalAttrs (s ? headers) { http_headers = s.headers; }
                // lib.optionalAttrs (s ? bearerTokenFile) {
                  http_headers_helper = "${pkgs.writeShellScript "codex-mcp-${name}-headers" ''
                    printf '{"Authorization":"Bearer %s"}' "$(cat "$HOME/${lib.removePrefix "~/" s.bearerTokenFile}")"
                  ''}";
                }
              else
                let
                  argv = lib.toList s.command ++ (s.args or [ ]);
                in
                {
                  command = builtins.head argv;
                  args = builtins.tail argv;
                }
                // lib.optionalAttrs ((s.env or { }) != { }) { inherit (s) env; }
            )
            (
              lib.foldl' (acc: e: acc // (e.mcpServers or { })) { } (
                lib.filter (e: e.type or "" == "mcp") extensionsList
              )
            );

        # Subagents are written in Claude Code's frontmatter; codex wants one TOML per agent
        # with name/description/developer_instructions. `tools` and `model` have no codex
        # meaning and are dropped: a codex subagent inherits its parent's sandbox and tools, so
        # gen-gate's and gen-scout's withheld Edit does NOT bind here.
        toAgentToml =
          pkgs.writers.writePython3 "codex-agent-toml"
            {
              libraries = with pkgs.python3Packages; [
                pyyaml
                tomli-w
              ];
            }
            ''
              import sys

              import tomli_w
              import yaml

              src, out = sys.argv[1:]
              text = open(src).read()
              if not text.startswith("---\n"):
                  sys.exit(f"{src}: no frontmatter")
              _, fm, body = text.split("---\n", 2)
              meta = yaml.safe_load(fm)
              agent = {
                  "name": meta["name"],
                  "description": " ".join(meta["description"].split()),
                  "developer_instructions": body.strip() + "\n",
              }
              with open(out, "wb") as f:
                  tomli_w.dump(agent, f, multiline_strings=True)
            '';
        agentTomls = lib.mapAttrs (
          name: src:
          pkgs.runCommand "codex-agent-${name}.toml" { } ''
            ${toAgentToml} ${src.outPath or src} $out
          ''
        ) (collect "agents" // collect "codexAgents");
        # Codex opens a role file with O_NOFOLLOW and refuses a symlink (exec-server
        # regular_file.rs), so a home.file store link is listed but fails at spawn ("agent type is
        # currently not available"). Copy each role in as a regular file instead; a manifest
        # records what this installed, so a role dropped from the declaration is removed and
        # files codex or the user put there are left alone.
        agentsDir = "${config.home.homeDirectory}/.codex/agents";
        installAgents = ''
          mkdir -p ${lib.escapeShellArg agentsDir}
          manifest=${lib.escapeShellArg agentsDir}/.nix-managed
          if [ -f "$manifest" ]; then
            while IFS= read -r old; do
              case " ${lib.concatStringsSep " " (map (n: "${n}.toml") (lib.attrNames agentTomls))} " in
                *" $old "*) ;;
                *) [ -n "$old" ] && rm -f ${lib.escapeShellArg agentsDir}/"$old" ;;
              esac
            done < "$manifest"
          fi
          ${lib.concatStrings (
            lib.mapAttrsToList (name: toml: ''
              rm -f ${lib.escapeShellArg "${agentsDir}/${name}.toml"}
              install -m 0644 ${toml} ${lib.escapeShellArg "${agentsDir}/${name}.toml"}
            '') agentTomls
          )}
          printf '%s\n' ${lib.escapeShellArgs (map (n: "${n}.toml") (lib.attrNames agentTomls))} > "$manifest"
        '';

        # bash-guard.sh is claude.nix's, at a stable home path so codex's hook trust (taken on
        # the hook definition) survives edits to the script. Codex's PreToolUse/Bash payload
        # carries tool_input.command and honours exit 2 + stderr, as claude's does.
        guard = ".claude/bash-guard.sh";
        # Gated on claude.nix's enable, which writes the script; probing home.file here recurses.
        guardHooks = lib.optionalAttrs config.programs.claude-code.enable {
          PreToolUse = [
            {
              matcher = "Bash";
              hooks = [
                {
                  type = "command";
                  command = "bash ${config.home.homeDirectory}/${guard}";
                }
              ];
            }
          ];
        };
        # Devshell per command, the codex analogue of claude.nix's load-direnv.sh. Codex has no
        # CwdChanged event and no hook-writable env file, but a PreToolUse hook may rewrite the
        # exec command (updatedInput needs permissionDecision:allow, which licenses the rewrite
        # only; the command still goes through approval, and any hook's deny drops every rewrite,
        # so bash-guard judges the original). The hook never evaluates: codex runs the ORIGINAL
        # command when a hook fails or times out (5 s), so a slow devshell build there would run
        # it with a stale env. Instead the rewrite prepends one line that loads the env and stops
        # on failure, then the original bytes, run by codex's own shell.
        #
        # The hook's `direnv export json` is the only evaluation, under the 12G cap (a devshell
        # build is a nix evaluation); the user's command runs uncapped (host builds are exempt).
        # Its JSON diff is against the hook's env, which codex gives the session's env, so
        # direnv's unload semantics (A to B, leaving every .envrc) come out as unsets.
        #
        # Limits: the hook's own failure or timeout is fail-open (a codex property); malformed or
        # cwd-less input is warning-only; a cd inside the command is not seen; the prefix is POSIX
        # sh, so a fish or nu shell fails loudly; and the prefix changes the entry status and adds
        # a command before the original bytes, so it is not transparent to a command that reads
        # its initial $? or depends on parse/prologue behaviour.
        # The hook runs OUTSIDE codex's sandbox and the command INSIDE it, where the user bus is
        # unreachable (measured 2026-11-09 on uplink-dev: systemd-run --user fails "Operation not
        # permitted" in every sandboxed exec_command). So the capped evaluation happens here, in
        # the hook, and the sandboxed command only sources the result. Its timeout is raised from
        # codex's 5 s default (handler `timeout` below) because a cold devshell builds here; a
        # failed or timed-out export is a DENY with direnv's error, never the original command.
        direnvHook = pkgs.writeShellApplication {
          name = "codex-direnv-hook";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.direnv
            pkgs.jq
          ];
          text = ''
            direnv=''${CODEX_DENV_DIRENV:-${lib.getExe pkgs.direnv}}
            systemd_run=''${CODEX_DENV_SYSTEMD_RUN:-/run/current-system/sw/bin/systemd-run}
            out_dir=''${CODEX_DENV_DIR:-''${XDG_RUNTIME_DIR:-/tmp}/codex-direnv}
            payload=$(cat)
            cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
            cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
            [ -n "$cmd" ] || exit 0
            if [ -z "$cwd" ] || [ ! -d "$cwd" ]; then
              jq -nc '{systemMessage: "codex-direnv: no usable cwd in the hook payload; devshell not applied"}'
              exit 0
            fi
            deny() {
              jq -nc --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse",
                permissionDecision: "deny", permissionDecisionReason: $r}}'
              exit 0
            }
            status=$(cd -- "$cwd" && "$direnv" status --json </dev/null 2>/dev/null) || exit 0
            found=$(printf '%s' "$status" | jq -r '.state.foundRC.path // empty')
            allowed=$(printf '%s' "$status" | jq -r '.state.foundRC.allowed // empty')
            if [ -z "$found" ] && [ -z "''${DIRENV_DIFF:-}" ]; then
              exit 0
            fi
            if [ -n "$found" ] && [ "$allowed" != 0 ]; then
              deny "$found is not allowed by direnv. Review it, then run: direnv allow $(printf '%s' "$found" | jq -Rr @sh) (or run the command from outside that directory)."
            fi
            err=$(mktemp)
            trap 'rm -f "$err"' EXIT
            rc=0
            json=$(cd -- "$cwd" && "$systemd_run" --user --scope -q -p MemoryMax=12G \
              timeout 1700 "$direnv" export json </dev/null 2>"$err") || rc=$?
            if [ "$rc" -ne 0 ]; then
              deny "devshell load failed (rc $rc) for $cwd; command not run. direnv: $(tail -c 1500 "$err")"
            fi
            if [ -z "$json" ]; then
              exit 0
            fi
            printf '%s' "$json" | jq -e 'type == "object" and (keys | all(test("^[A-Za-z_][A-Za-z0-9_]*$")))' \
              >/dev/null 2>&1 || deny "devshell load failed: direnv returned malformed JSON or a non-identifier key; command not run."
            # One statement per line, chained with &&, so any failing assignment (a readonly
            # variable) fails the whole source and the command never runs with a partial env.
            stmts=$(printf '%s' "$json" | jq -r '[to_entries[]
              | if .value == null then "unset \(.key)" else "export \(.key)=\(.value | @sh)" end]
              | join(" &&\n")')
            mkdir -p "$out_dir" && chmod 0700 "$out_dir"
            f="$out_dir/$(printf '%s' "$stmts" | sha256sum | cut -c1-32).sh"
            [ -s "$f" ] || { printf '%s\n' "$stmts" > "$f.$$" && chmod 0600 "$f.$$" && mv -f "$f.$$" "$f"; }
            prefix=". $(printf '%s' "$f" | jq -Rr @sh) || exit \$?"
            jq -nc --arg c "$prefix
            $cmd" '{hookSpecificOutput: {hookEventName: "PreToolUse",
              permissionDecision: "allow", updatedInput: {command: $c}}}'
          '';
        };
        direnvHooks = {
          PreToolUse = [
            {
              matcher = "Bash";
              hooks = [
                {
                  type = "command";
                  command = lib.getExe direnvHook;
                  # Above the inner timeout 1700, so a cold devshell build ends in the hook's
                  # own deny rather than in codex's fail-open timeout.
                  timeout = 1800;
                }
              ];
            }
          ];
        };

        # ★ THE GEN-ORCHESTRATION HOOKS, PORTED. Codex fires the same event names with the same
        # session_id/cwd/hook_event_name/source fields, takes plain SessionStart stdout as model
        # context, and takes hookSpecificOutput.additionalContext on SubagentStart, PreToolUse and
        # UserPromptSubmit, so gated.sh and the scripts below run unchanged there. Ported as-is:
        # the xmsg-design boot, the beads boot and drift checks, the compaction commission, and
        # the hindsight recall for gen roles (it reads agent_type, which codex fills with the role).
        # Ported with codex wording: the subagent brief. Ported with a codex data source: the
        # budget (codex-budget below). NOT portable, by codex design: PreCompact can stop a turn
        # or warn but cannot steer the summary, so pre-compact.sh's summary steering and hold
        # have no codex equivalent (recovery runs at SessionStart(compact) instead), and
        # SubagentStop's output goes to the subagent, not the parent, so subagent-stop.sh's
        # parent reminder has nowhere to land (the parent gets the child's final through
        # wait_agent). Out of scope: rtk, cbm and the search augmenter.
        claudeHook =
          name:
          let
            cmds = lib.filter (c: lib.hasInfix name c) (
              map (h: toString h.command) (
                lib.concatMap (g: g.hooks) (
                  lib.concatLists (lib.attrValues config.programs.claude-code.settings.hooks)
                )
              )
            );
          in
          if cmds == [ ] then
            throw "codex.nix: no claude hook command contains `${name}` to port"
          else
            lib.head cmds;
        cmdHook = command: {
          type = "command";
          inherit command;
        };
        # Codex's own measurements, never Claude's: the session log's last token_count event
        # (last_token_usage.total_tokens, which codex itself counts as the tokens in context,
        # protocol.rs tokens_in_context_window, over model_context_window) and its rate_limits
        # (primary/secondary used_percent with their window_minutes). Anything absent is `?`,
        # never estimated. Same gates and delivery as budget.sh: SessionStart prints the line;
        # PreToolUse and UserPromptSubmit speak only when the gate changes.
        codexBudget = pkgs.writeShellApplication {
          name = "codex-budget";
          # gated.sh (claude.nix) is sourced at run time and defines hook_field and marker.
          excludeShellChecks = [
            "SC1091"
            "SC2154"
          ];
          runtimeInputs = [
            pkgs.coreutils
            pkgs.gawk
            pkgs.jq
          ];
          text = ''
            event=''${1:-manual}
            . "$HOME/.claude/gated.sh" 2>/dev/null || exit 0
            [ "$event" = manual ] || gated || exit 0
            tp=$(hook_field .transcript_path)
            rec=""
            if [ -n "$tp" ] && [ -s "$tp" ]; then
              rec=$(tail -n 2000 "$tp" | jq -c 'select(.type == "event_msg" and .payload.type == "token_count") | .payload' 2>/dev/null | tail -n 1)
            fi
            num() { case "$1" in "" | null | *[!0-9.]*) echo "?" ;; *) echo "$1" ;; esac; }
            tok=$(num "$(printf '%s' "$rec" | jq -r '.info.last_token_usage.total_tokens // empty' 2>/dev/null)")
            win=$(num "$(printf '%s' "$rec" | jq -r '.info.model_context_window // empty' 2>/dev/null)")
            ctx="?"
            if [ "$tok" != "?" ] && [ "$win" != "?" ] && [ "$win" != 0 ]; then
              ctx=$(awk -v t="$tok" -v w="$win" 'BEGIN{printf "%.1f", t*100/w}')
            fi
            limits=""
            weekly="?"
            for k in primary secondary; do
              used=$(num "$(printf '%s' "$rec" | jq -r ".rate_limits.$k.used_percent // empty" 2>/dev/null)")
              mins=$(num "$(printf '%s' "$rec" | jq -r ".rate_limits.$k.window_minutes // empty" 2>/dev/null)")
              [ "$used" = "?" ] && continue
              limits="$limits · codex-$k $used% (''${mins}m window)"
              [ "$mins" = 10080 ] && weekly=$used
            done
            gate=""
            if [ "$ctx" != "?" ]; then
              gate=$(awk -v c="$ctx" 'BEGIN{
                if (c+0 >= 90)      print "CLOSE OUT (ctx>=90) - the rest of the window is the handoff";
                else if (c+0 >= 75) print "NO FRESH SUBJECTS (ctx>=75) - finish open streams, start nothing new";
              }')
            fi
            if [ "$weekly" != "?" ] && awk -v w="$weekly" 'BEGIN{exit !(w+0>=95)}'; then
              gate="CLEAN CLOSEOUT (7d>=95) - unhurried; finish in-flight, no new dispatch"
            fi
            src="codex session log: last_token_usage.total_tokens $tok / model_context_window $win"
            [ -n "$rec" ] || src="codex session log: no token_count record yet"
            line="BUDGET $event · ctx $ctx% ($src)$limits''${gate:+ · GATE: $gate}"
            if [ "$event" != SessionStart ] && [ "$event" != manual ]; then
              seen="$marker.codex-gate.$event"
              if [ -z "$gate" ]; then rm -f "$seen"; exit 0; fi
              [ "$gate" != "$(cat "$seen" 2>/dev/null)" ] || exit 0
              printf '%s' "$gate" > "$seen"
            fi
            case "$event" in
              PreToolUse | UserPromptSubmit)
                printf '%s' "$line" | jq -Rs --arg ev "$event" '{hookSpecificOutput: {hookEventName: $ev, additionalContext: .}}'
                ;;
              *) printf '%s\n' "$line" ;;
            esac
          '';
        };
        # subagent-brief.sh's invariants in codex terms: the final message is the delivery.
        codexBrief = pkgs.writeShellScript "codex-subagent-brief" ''
          . "$HOME/.claude/gated.sh" 2>/dev/null || exit 0
          gated || exit 0
          ${lib.getExe pkgs.jq} -nc --arg c "Brief invariants (den-ag-design fleet): Write your report as a file, and end with it as your final message, which codex returns to the orchestrator through wait_agent. Write scratch only under <scratchpad>/<agent-name>-private/. Never pkill -f, killall, or kill on pgrep -f output; kill only a PID captured with \$!. Wait on a \$! PID or a producer-written marker, always under timeout. Run every nix eval, nix build, nix flake check and nix-unit under systemd-run --user --scope -q -p MemoryMax=12G, except nix-flake-build host builds." \
            '{hookSpecificOutput: {hookEventName: "SubagentStart", additionalContext: $c}}'
        '';
        orchestrationHooks = lib.optionalAttrs config.programs.claude-code.enable {
          SessionStart = [
            {
              hooks = [
                (cmdHook "bash ${config.home.homeDirectory}/.claude/xmsg-session-boot.sh || true")
                (cmdHook "${claudeHook "beads-tracker-drift"}")
                (cmdHook "${claudeHook "beads-session-boot"}")
                (cmdHook "${lib.getExe codexBudget} SessionStart || true")
              ];
            }
            {
              matcher = "compact";
              hooks = [ (cmdHook "bash ${config.home.homeDirectory}/.claude/handoff-commission.sh || true") ];
            }
          ];
          SubagentStart = [
            {
              hooks = [
                (cmdHook "${claudeHook "hindsight-subagent-recall"}")
                (cmdHook "${codexBrief}")
              ];
            }
          ];
          UserPromptSubmit = [
            { hooks = [ (cmdHook "${lib.getExe codexBudget} UserPromptSubmit || true") ]; }
          ];
          PreToolUse = [ { hooks = [ (cmdHook "${lib.getExe codexBudget} PreToolUse || true") ]; } ];
        };

        # xmsg's lifecycle hooks after the guard, lists joined per event. Codex keys hook trust
        # by position (event:group:handler), so this order must stay stable: the direnv rewrite
        # is appended after the guard and xmsg.
        hooks = lib.zipAttrsWith (_: lib.concatLists) [
          guardHooks
          config.programs.xmsg.harnesses.codex.hooks
          direnvHooks
          orchestrationHooks
        ];
        hooksPath = "${config.home.homeDirectory}/.codex/hooks.json";
      in
      {
        programs.codex = {
          enable = true;
          package = inputs'.llm-agents.packages.codex;
          inherit skills;
          # The same user-scope rules claude loads, as codex's one global instructions file.
          context = lib.concatMapStringsSep "\n\n" (r: if builtins.isPath r then builtins.readFile r else r) (
            lib.attrValues config.programs.claude-code.rules
          );
          settings.mcp_servers = mcpServers;
        };

        home.file = {
          ".codex/config.toml".enable = lib.mkForce false;
          ".codex/hooks.json" = lib.mkIf (hooks != { }) { text = builtins.toJSON { inherit hooks; }; };
        };

        # After linkGeneration, which removes the previous generation's agent symlinks.
        home.activation.codexAgents = lib.hm.dag.entryAfter [ "linkGeneration" ] installAgents;

        lens.files.codex = {
          target = ".codex/config.toml";
          settings = lib.recursiveUpdate config.programs.codex.settings (
            config.programs.xmsg.harnesses.codex.trustState hooksPath { inherit hooks; }
          );
        };

        programs.git.ignores = [ "/.codex/" ];
      };

    # auth.json (the ChatGPT login), sessions, history and the runtime-written config.toml.
    persistHome.directories = [ ".codex" ];
  };
}
