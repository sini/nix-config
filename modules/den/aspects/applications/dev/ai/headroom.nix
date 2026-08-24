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
            Environment = [ "HEADROOM_TELEMETRY=off" ];
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
            EnvironmentVariables = {
              HEADROOM_TELEMETRY = "off";
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
