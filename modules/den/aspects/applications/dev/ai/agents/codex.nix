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
        ) (collect "agents");
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
        # xmsg's lifecycle hooks after the guard, lists joined per event. Codex keys hook trust
        # by position (event:group:handler), so this order must stay stable.
        hooks = lib.zipAttrsWith (_: lib.concatLists) [
          guardHooks
          config.programs.xmsg.harnesses.codex.hooks
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
