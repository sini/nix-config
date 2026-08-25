# codegraph (github:colbymchenry/codegraph): Semantic code intelligence and
# fast 100% local code graph for AI coding agents. Package comes from
# llm-agents.nix.
{
  den.aspects.applications.dev.ai.codegraph = {
    homeManager =
      { inputs', ... }:
      let
        codegraph = inputs'.llm-agents.packages.codegraph;
      in
      {
        home.packages = [ codegraph ];

        programs.claude-code = {
          # `serve --mcp` is the server entrypoint (`codegraph install --print-config claude`
          # emits exactly this). Bare `codegraph` is the CLI: it prints help and exits, so
          # the handshake never completes and the client sits on it until the startup
          # timeout, then picks the tools up mid-session — a tool-list change, which costs
          # a full prompt-cache bust.
          mcpServers.codegraph = {
            type = "stdio";
            command = "${codegraph}/bin/codegraph";
            args = [
              "serve"
              "--mcp"
            ];
          };

          settings.permissions.allow = [
            "Bash(codegraph *)"
          ];
        };

        programs.git.ignores = [
          ".codegraph"
        ];
      };
  };
}
