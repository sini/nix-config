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
{ ... }:
{
  den.aspects.apps.dev.ai.claude-config = {

    homeManager =
      { pkgs, ... }:
      {
        # Don't track ~/.claude in any repo.
        programs.git.ignores = [ ".claude" ];

        # Read-only, declarative — the cortex canonical, rendered to the store.
        home.file.".claude/settings.json".source = (pkgs.formats.json { }).generate "claude-settings.json" {
          env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
          teammateMode = "in-process";
          permissions = {
            allow = [
              "Bash(wc:*)"
              "WebFetch(domain:raw.githubusercontent.com)"
            ];
            defaultMode = "default";
          };
          enabledPlugins = {
            "commit-commands@claude-plugins-official" = true;
            "caveman@caveman" = true;
            "skill-creator@claude-plugins-official" = true;
            "code-simplifier@claude-plugins-official" = true;
            "superpowers-extended-cc@superpowers-extended-cc-marketplace" = true;
            "rust-analyzer-lsp@claude-plugins-official" = true;
          };
          extraKnownMarketplaces = {
            superpowers-marketplace.source = {
              source = "github";
              repo = "obra/superpowers-marketplace";
            };
            superpowers-extended-cc-marketplace.source = {
              source = "github";
              repo = "pcvelz/superpowers";
            };
            caveman.source = {
              source = "github";
              repo = "JuliusBrussee/caveman";
            };
          };
          effortLevel = "xhigh";
          tui = "default";
          autoMemoryDirectory = "~/.claude/memory";
          skipWorkflowUsageWarning = true;
          verbose = true;
          inputNeededNotifEnabled = true;
          agentPushNotifEnabled = true;
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
  };
}
