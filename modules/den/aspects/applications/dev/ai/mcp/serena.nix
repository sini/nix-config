# serena (github:oraios/serena, PyPI: serena-agent): Semantic code-navigation MCP server.
{ ... }:
{
  den.aspects.applications.dev.ai.mcp.serena = {
    homeManager =
      { pkgs, lib, ... }:
      {
        home.packages = [
          pkgs.local.serena-agent
        ];

        programs.git.ignores = [
          ".serena"
        ];

        programs.claude-code = {
          mcpServers.serena = {
            type = "stdio";
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

          settings.permissions.allow = [
            "Bash(serena *)"
          ];
        };
      };
  };
}
