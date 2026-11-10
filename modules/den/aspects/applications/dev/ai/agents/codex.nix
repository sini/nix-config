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
        # codex-direnv-env is the only direnv evaluation, under the 12G cap (a devshell build is
        # a nix evaluation); the user's command runs uncapped (host builds are exempt). Its JSON
        # diff is against the caller's env, so direnv's unload semantics (A to B, leaving every
        # .envrc) come out as unsets.
        #
        # Limits: the hook's own failure or timeout is fail-open (a codex property); malformed or
        # cwd-less input is warning-only; a cd inside the command is not seen; the prefix is POSIX
        # sh, so a fish or nu shell fails loudly; and the prefix changes the entry status and adds
        # a command before the original bytes, so it is not transparent to a command that reads
        # its initial $? or depends on parse/prologue behaviour.
        direnvEnv = pkgs.writeShellApplication {
          name = "codex-direnv-env";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.jq
          ];
          text = ''
            # usage: codex-direnv-env DIR — POSIX statements applying DIR's devshell env, or exit
            # nonzero printing nothing on stdout.
            direnv=''${CODEX_DENV_DIRENV:-${lib.getExe pkgs.direnv}}
            systemd_run=''${CODEX_DENV_SYSTEMD_RUN:-/run/current-system/sw/bin/systemd-run}
            fail() {
              printf 'codex-direnv-env: %s; command not run\n' "$1" >&2
              exit "$2"
            }
            cd -- "$1" 2>/dev/null || fail "cannot enter $1" 66
            err=$(mktemp)
            trap 'rm -f "$err"' EXIT
            rc=0
            out=$("$systemd_run" --user --scope -q -p MemoryMax=12G \
              timeout 1800 "$direnv" export json </dev/null 2>"$err") || rc=$?
            if [ "$rc" -ne 0 ]; then
              cat "$err" >&2
              fail "devshell load failed (rc $rc)" "$rc"
            fi
            [ -n "$out" ] || exit 0
            printf '%s' "$out" | jq -e 'type == "object" and (keys | all(test("^[A-Za-z_][A-Za-z0-9_]*$")))' \
              >/dev/null 2>&1 || fail "direnv returned malformed JSON or a non-identifier key" 65
            printf '%s' "$out" | jq -r 'to_entries[]
              | if .value == null then "unset \(.key)" else "export \(.key)=\(.value | @sh)" end'
          '';
        };
        direnvHook = pkgs.writeShellApplication {
          name = "codex-direnv-hook";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.direnv
            pkgs.jq
          ];
          text = ''
            payload=$(cat)
            cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
            cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
            [ -n "$cmd" ] || exit 0
            if [ -z "$cwd" ] || [ ! -d "$cwd" ]; then
              jq -nc '{systemMessage: "codex-direnv: no usable cwd in the hook payload; devshell not applied"}'
              exit 0
            fi
            status=$(cd -- "$cwd" && direnv status --json </dev/null 2>/dev/null) || exit 0
            found=$(printf '%s' "$status" | jq -r '.state.foundRC.path // empty')
            allowed=$(printf '%s' "$status" | jq -r '.state.foundRC.allowed // empty')
            if [ -z "$found" ] && [ -z "''${DIRENV_DIFF:-}" ]; then
              exit 0
            fi
            if [ -n "$found" ] && [ "$allowed" != 0 ]; then
              jq -nc --arg p "$found" '{hookSpecificOutput: {hookEventName: "PreToolUse",
                permissionDecision: "deny",
                permissionDecisionReason: "\($p) is not allowed by direnv. Review it, then run: direnv allow \($p | @sh) (or run the command from outside that directory)."}}'
              exit 0
            fi
            prefix="__codex_denv=\$(${lib.getExe direnvEnv} $(printf '%s' "$cwd" | jq -Rr @sh)) || exit \$?; eval \"\$__codex_denv\" || exit \$?; unset __codex_denv"
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
                }
              ];
            }
          ];
        };

        # xmsg's lifecycle hooks after the guard, lists joined per event. Codex keys hook trust
        # by position (event:group:handler), so this order must stay stable: the direnv rewrite
        # is appended after the guard and xmsg.
        hooks = lib.zipAttrsWith (_: lib.concatLists) [
          guardHooks
          config.programs.xmsg.harnesses.codex.hooks
          direnvHooks
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
