# headroom (github:headroomlabs-ai/headroom): Context compression layer for AI agents.
# Ships a store-pinned plugin containing native startup and compression hooks,
# backed by a local proxy server and CLI binary (pkgs.local.headroom-ai).
{ inputs, ... }:
{
  flake-file.inputs.headroom = {
    url = "github:headroomlabs-ai/headroom";
    flake = false;
  };

  den.aspects.applications.dev.ai.headroom = {
    homeManager =
      { pkgs, lib, ... }:
      {
        home.packages = [
          pkgs.local.headroom-ai
          pkgs.uv
        ];

        programs.claude-code = {
          marketplaces.headroom-marketplace = inputs.headroom;
          mcpServers.headroom = {
            type = "stdio";
            command = "${lib.getExe pkgs.local.headroom-ai}";
            args = [
              "mcp"
              "serve"
            ];
          };
          settings = {
            enabledPlugins."headroom@headroom-marketplace" = true;
            env = {
              ANTHROPIC_BASE_URL = "http://127.0.0.1:8787";
              HEADROOM_1M = "1";
            };
            permissions.allow = [
              "Bash(headroom *)"
            ];
          };
        };
      };

    homeLinux =
      { pkgs, lib, ... }:
      {
        systemd.user.services.headroom = {
          Unit = {
            Description = "Headroom token-compression proxy for AI coding agents";
            Documentation = [ "https://github.com/headroomlabs-ai/headroom" ];
            After = [ "network-online.target" ];
            Wants = [ "network-online.target" ];
          };

          Service = {
            # HEADROOM_MODE=cache is upstream's default, pinned here because it is
            # load-bearing: `token` mode rewrites prior turns for maximum compression,
            # and a rewritten turn changes the request prefix bytes, so every rewrite
            # costs a provider prefix-cache bust. `cache` freezes prior turns and
            # compresses the delta only.
            #
            # FREEZE_BLOCK_DECISION ships off. Without it a block's compress-vs-passthrough
            # verdict is recomputed per turn against a drifting min_ratio, so the same
            # historical block can be compressed on turn N and passed through on turn N+1 —
            # the bytes change underneath an already-cached prefix and the whole conversation
            # is re-created (upstream: content_router "Cache-churn fix", release note
            # "pin FREEZE_BLOCK_DECISION verdict to stop cache-write churn"). Freezing the
            # verdict on first sighting costs a little compression on blocks judged early;
            # the proxy's own `headroom_cache_bust_tokens_lost_total` counter measures the
            # trade at http://127.0.0.1:8787/metrics.
            Environment = [
              "HEADROOM_TELEMETRY=off"
              "HEADROOM_MODE=cache"
              "HEADROOM_FREEZE_BLOCK_DECISION=1"
            ];
            ExecStart = "${lib.getExe pkgs.local.headroom-ai} proxy --host 127.0.0.1 --port 8787 --no-telemetry";
            Restart = "on-failure";
            RestartSec = 5;
            TimeoutStartSec = "infinity";
          };

          Install.WantedBy = [ "default.target" ];
        };
      };

    homeDarwin =
      { pkgs, lib, ... }:
      {
        launchd.agents.headroom = {
          enable = true;
          config = {
            ProgramArguments = [
              "${lib.getExe pkgs.local.headroom-ai}"
              "proxy"
              "--host"
              "127.0.0.1"
              "--port"
              "8787"
              "--no-telemetry"
            ];
            # Mirrors the Linux service environment — see there for why these two are set.
            EnvironmentVariables = {
              HEADROOM_TELEMETRY = "off";
              HEADROOM_MODE = "cache";
              HEADROOM_FREEZE_BLOCK_DECISION = "1";
            };
            KeepAlive = {
              Crashed = true;
              SuccessfulExit = false;
            };
            ProcessType = "Background";
            RunAtLoad = true;
            ThrottleInterval = 5;
          };
        };
      };
  };
}
