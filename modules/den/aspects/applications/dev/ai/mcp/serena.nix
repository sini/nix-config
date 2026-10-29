# serena (github:oraios/serena, PyPI: serena-agent): Semantic code-navigation MCP server.
{ ... }:
{
  den.aspects.applications.dev.ai.mcp.serena = {
    agent-extensions =
      { lib, pkgs, ... }:
      {
        type = "mcp";
        # Linux-only: see pkgs/by-name/serena-agent meta.platforms.
        mcpServers = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          serena = {
            command = "${lib.getExe pkgs.local.serena-agent}";
            args = [
              "start-mcp-server"
              "--project-from-cwd"
              "--context"
              "claude-code"
              "--open-web-dashboard"
              "False"
            ];
          };
        };
      };

    homeManager =
      { pkgs, lib, ... }:
      {
        home.packages = lib.optionals pkgs.stdenv.hostPlatform.isLinux [
          pkgs.local.serena-agent
        ];

        programs.git.ignores = [
          ".serena"
        ];

        programs.claude-code = {
          settings.permissions.allow = [
            "Bash(serena *)"
          ];
        };
      };
  };
}
