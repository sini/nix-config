# headroom (github:headroomlabs-ai/headroom): Context compression layer for AI agents.
# Ships a store-pinned plugin containing native startup and compression hooks,
# backed by a local proxy server and CLI binary (pkgs.local.headroom-ai).
{ inputs, ... }:
{
  flake-file.inputs.headroom = {
    url = "github:headroomlabs-ai/headroom";
    flake = false;
  };

  den.aspects.applications.dev.ai.mcp.headroom = {
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
            # FREEZE_BLOCK_DECISION is deliberately NOT set — upstream ships it off and
            # enabling it here measured worse. It pins a block's compress-vs-passthrough
            # verdict on first sighting so a drifting min_ratio cannot flip an already-cached
            # block back to original text. But `_frozen_verdicts` is one process-wide dict
            # capped at 4096 with FIFO eviction, shared by every concurrent session, so on a
            # busy fleet the pins age out and the verdict is recomputed anyway — the freeze
            # defers the churn rather than removing it. Enabled across a fleet-wide window it
            # logged zero FREEZE-PIN hits (its own payoff counter, INFO level) while the bust
            # rate on matched long-context sessions went from 0.65 to 2.93 per 100 requests.
            # Re-measure with `headroom_cache_bust_tokens_lost_total` at
            # http://127.0.0.1:8787/metrics before enabling it again.
            # HEADROOM_LOSSLESS drops the LOSSY compressors for format-native lossless
            # compaction. Lossy compression measured NET NEGATIVE against the prompt cache:
            # over one fleet-wide window it removed 5,318,047 tokens while the proxy's own
            # `headroom_cache_bust_tokens_lost_total` ("tokens that lost provider cache
            # discount because of compression") recorded 5,327,329 — one token knocked out
            # of cache per token saved. The prices are not symmetric: a cached token bills
            # at 0.1x and its re-write at 2.0x on the 1h TTL (headroom's own
            # CACHE_READ_MULTIPLIER / CACHE_WRITE_MULTIPLIER_1H), so that trade runs 20:1
            # against. This is not a policy misconfiguration to tune around — the client UA
            # is `claude-cli/`, which auth_policy classifies SUBSCRIPTION, already headroom's
            # most cache-conservative policy (live_zone_only, cache aligner off, 25% cap).
            # The savings that survive are tool_search's, an order of magnitude larger and
            # earned by deferring tool schemas rather than by rewriting cached bytes.
            # Lossless also ends the agent-side workaround tax: a lossy rendering is not the
            # artefact, so every verbatim-critical read had to go dump-to-file and back.
            #
            # HEADROOM_LOG_MESSAGES makes the proxy store pre/post-compression
            # message snapshots, which is the ONLY thing `headroom inspect` reads.
            # Without it that command refuses outright ("the proxy isn't capturing
            # message content"), so there is no way to answer the question it exists
            # to answer: WHICH layer elided a tool result. That matters because the
            # elisions are attributable by guess otherwise — `Bash` sits in
            # --protect-tool-results' built-in defaults, yet Bash results still come
            # back word-dropped against the bytes on disk, so either the protection
            # is not doing what its help says or the harness display layer is
            # responsible. An unattributed lossy channel is the thing that makes a
            # gate report clean without having measured anything.
            #
            # COST, deliberately accepted: request/response CONTENT lands in the log
            # file and on the live-feed endpoint (upstream: "may log sensitive
            # data"). The proxy binds 127.0.0.1 only and telemetry is off above, and
            # the logs are routed to the cache bucket below so they are never backed
            # up or replicated.
            Environment = [
              "HEADROOM_TELEMETRY=off"
              "HEADROOM_MODE=cache"
              "HEADROOM_LOSSLESS=1"
              "HEADROOM_LOG_MESSAGES=1"
            ];
            ExecStart = "${lib.getExe pkgs.local.headroom-ai} proxy --host 127.0.0.1 --port 8787 --no-telemetry";
            Restart = "on-failure";
            RestartSec = 5;
            TimeoutStartSec = "infinity";
          };

          Install.WantedBy = [ "default.target" ];
        };
      };

    # Message content and the CCR original-bytes store are regenerable scratch on a
    # separate dataset that is not backed up — deliberately NOT persistHome, since
    # both hold verbatim conversation content.
    cacheHome.directories = [
      ".headroom/logs"
      ".headroom/clients"
    ];

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
            # Mirrors the Linux service environment — see there for why these are set.
            EnvironmentVariables = {
              HEADROOM_TELEMETRY = "off";
              HEADROOM_MODE = "cache";
              HEADROOM_LOSSLESS = "1";
              HEADROOM_LOG_MESSAGES = "1";
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
