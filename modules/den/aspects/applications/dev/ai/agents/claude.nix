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
          acc: e:
          if (e ? skills) then
            acc // (lib.mapAttrs (_: src: src.outPath or src) e.skills)
          else
            acc
        ) { } skillExts;

        claudeAgents = lib.foldl' (
          acc: e: if (e ? agents) then acc // e.agents else acc
        ) { } extensionsList;

        claudeCommands = lib.foldl' (
          acc: e: if (e ? commands) then acc // e.commands else acc
        ) { } extensionsList;

        claudeMcpServers = lib.foldl' (
          acc: e:
          acc
          // (lib.mapAttrs (_name: server: {
            type = "stdio";
            inherit (server) command;
            args = server.args or [ ];
            env = server.env or { };
          }) (e.mcpServers or { }))
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
            };
          };
        };

        # RETIRED: `.claude/env.sh` used to live here, on the belief that Claude Code sources it.
        # It does not. Measured against claude-code 2.1.229: `env.sh` occurs ZERO times in the
        # binary, with live controls in the same run (`settings.json` 201, `CLAUDE.md` 201,
        # `.claude` 2933). It never ran. The supported mechanism is CLAUDE_ENV_FILE above.
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
