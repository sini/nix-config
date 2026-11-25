# headroom (github:headroomlabs-ai/headroom): Context compression layer for AI agents.
# Ships a store-pinned plugin containing native startup and compression hooks,
# backed by a local proxy server and CLI binary (pkgs.local.headroom-ai).
{ inputs, lib, ... }:
let
  # One proxy per user, all on loopback: offset by uid so users sharing a host never collide
  # (uid 1000 keeps 8787). Every consumer below reads this.
  portFor = user: 8787 + (user.system.uid or 1000) - 1000;

  # Every agent's API calls go through the proxy, so a proxy that is down or hung fails
  # them all. The check asks /livez twice, 5 s apart, and restarts the proxy only if both
  # go unanswered and it has been up for 2 minutes (a slow start is not a hang).
  # `restart` is the platform's restart command; `upSeconds` prints the proxy's uptime.
  livenessCheck =
    pkgs: user:
    { restart, upSeconds }:
    pkgs.writeShellScript "headroom-liveness" ''
      url=http://127.0.0.1:${toString (portFor user)}/livez
      alive() { ${pkgs.curl}/bin/curl -fsS -o /dev/null --max-time 10 "$url"; }
      up=$(${upSeconds}) || up=0
      [ "''${up:-0}" -ge 120 ] || exit 0
      alive && exit 0
      sleep 5
      alive && exit 0
      echo "headroom: $url unanswered twice after ''${up}s up; restarting the proxy" >&2
      ${restart}
    '';
in
{
  flake-file.inputs.headroom = {
    url = "github:headroomlabs-ai/headroom";
    flake = false;
  };

  den.aspects.applications.dev.ai.mcp.headroom = {
    # Off: agents reach the API directly. The proxy (headroom.service, its liveness check)
    # still runs, so a session started while this was on keeps a live proxy until it ends;
    # a session started after it is off never touches the proxy.
    settings.claude = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Route Claude through the headroom proxy (ANTHROPIC_BASE_URL), and give agents headroom's MCP server and its Bash permission.";
    };

    agent-extensions =
      {
        host,
        lib,
        pkgs,
        ...
      }:
      {
        type = "mcp";
        mcpServers = lib.optionalAttrs host.settings.applications.dev.ai.mcp.headroom.claude {
          headroom = {
            command = "${lib.getExe pkgs.local.headroom-ai}";
            args = [
              "mcp"
              "serve"
            ];
          };
        };
      };

    homeManager =
      {
        host,
        pkgs,
        lib,
        user,
        ...
      }:
      {
        home.packages = [
          pkgs.local.headroom-ai
          pkgs.uv
        ];

        programs.claude-code = lib.mkIf host.settings.applications.dev.ai.mcp.headroom.claude {
          # ★ THE PLUGIN IS NOT INSTALLED — it was a reference, and installing it was a
          # mistake (owner, 2026-09-02). Its hooks are `headroom init hook ensure` on
          # SessionStart and PreToolUse, and what that ENSURES is a self-heal hook written
          # into ~/.claude/settings.local.json with an ABSOLUTE STORE PATH baked in.
          #
          # That cannot work here. Measured 2026-09-02: the entry pinned
          # l9zgs4zw…-headroom-ai-0.36.5 while the live binary was
          # 8sf78ady…-headroom-ai-0.36.5 — SAME VERSION, different hash, because the
          # closure was rebuilt underneath it. So it breaks on ANY rebuild touching ANY
          # dependency, not on upgrades, and deleting the stale entry does not help: the
          # plugin rewrites it with the path of the day and it goes stale again.
          #
          # Nothing is lost. Compression runs through the proxy (ANTHROPIC_BASE_URL below)
          # and the MCP server above, both from pkgs.local.headroom-ai. The plugin's only
          # contribution was the hook that installs the broken hook.
          settings = {
            env = {
              ANTHROPIC_BASE_URL = "http://127.0.0.1:${toString (portFor user)}";
              HEADROOM_1M = "1";
            };
            permissions.allow = [
              "Bash(headroom *)"
            ];
          };
        };
      };

    homeLinux =
      {
        pkgs,
        lib,
        user,
        ...
      }:
      {
        systemd.user.services.headroom = {
          Unit = {
            Description = "Headroom token-compression proxy for AI coding agents";
            # Never give up restarting: every agent on this host depends on it.
            StartLimitIntervalSec = 0;
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
            # http://127.0.0.1:<port>/metrics (portFor) before enabling it again.
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
            ExecStart = "${lib.getExe pkgs.local.headroom-ai} proxy --host 127.0.0.1 --port ${toString (portFor user)} --no-telemetry";
            # `always`, not `on-failure`: a plain kill (SIGTERM) shuts the server down
            # gracefully with exit 0, which on-failure treats as done.
            Restart = "always";
            RestartSec = 2;
            TimeoutStartSec = "infinity";
          };

          Install.WantedBy = [ "default.target" ];
        };

        # A hung proxy is alive to systemd; this restarts one that stops answering.
        systemd.user.services.headroom-liveness = {
          Unit.Description = "Restart the headroom proxy if it stops answering";
          Service = {
            Type = "oneshot";
            ExecStart = livenessCheck pkgs user {
              restart = "${pkgs.systemd}/bin/systemctl --user restart headroom.service";
              upSeconds = lib.escapeShellArgs [
                "${pkgs.bash}/bin/bash"
                "-c"
                ''
                  [ "$(${pkgs.systemd}/bin/systemctl --user is-active headroom.service)" = active ] || { echo 0; exit; }
                  t=$(${pkgs.systemd}/bin/systemctl --user show headroom.service -p ActiveEnterTimestampMonotonic --value)
                  read -r now _ < /proc/uptime
                  echo $(( ''${now%.*} - t / 1000000 ))
                ''
              ];
            };
          };
        };
        systemd.user.timers.headroom-liveness = {
          Unit.Description = "Check the headroom proxy every 30 s";
          Timer = {
            OnActiveSec = "2min";
            OnUnitActiveSec = "30s";
            AccuracySec = "5s";
          };
          Install.WantedBy = [ "timers.target" ];
        };
      };

    # Message content and the CCR original-bytes store are regenerable scratch on a
    # separate dataset that is not backed up — deliberately NOT persistHome, since
    # both hold verbatim conversation content.
    cacheHome.directories = [
      ".headroom/logs"
      ".headroom/clients"
      ".headroom/config"
    ];
    # Its install and subscription state, beside the scratch above.
    cacheHome.files = [
      ".headroom/mcp_installs.json"
      ".headroom/subscription_state.json"
    ];

    homeDarwin =
      {
        pkgs,
        lib,
        user,
        ...
      }:
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
              (toString (portFor user))
              "--no-telemetry"
            ];
            # Mirrors the Linux service environment — see there for why these are set.
            EnvironmentVariables = {
              HEADROOM_TELEMETRY = "off";
              HEADROOM_MODE = "cache";
              HEADROOM_LOSSLESS = "1";
              HEADROOM_LOG_MESSAGES = "1";
            };
            # Restarted however it ends: a plain kill shuts the server down with exit 0.
            KeepAlive = true;
            ProcessType = "Background";
            RunAtLoad = true;
            ThrottleInterval = 5;
          };
        };

        # A hung proxy is alive to launchd; this restarts one that stops answering.
        launchd.agents.headroom-liveness = {
          enable = true;
          config = {
            ProgramArguments = [
              "${livenessCheck pkgs user {
                restart = "/bin/launchctl kickstart -k gui/$(/usr/bin/id -u)/org.nix-community.home.headroom";
                upSeconds = lib.escapeShellArgs [
                  "/bin/sh"
                  "-c"
                  ''
                    pid=$(/bin/launchctl print gui/$(/usr/bin/id -u)/org.nix-community.home.headroom 2>/dev/null | /usr/bin/awk '$1 == "pid" { print $3 }')
                    [ -n "$pid" ] || { echo 0; exit; }
                    /bin/ps -o etimes= -p "$pid" | /usr/bin/tr -d ' '
                  ''
                ];
              }}"
            ];
            StartInterval = 30;
            RunAtLoad = false;
            ProcessType = "Background";
          };
        };
      };
  };
}
