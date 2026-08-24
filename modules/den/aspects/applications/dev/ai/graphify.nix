# graphify (github:Graphify-Labs/graphify): Turn any folder of code, docs,
# papers, images, or videos into a queryable knowledge graph.
{ inputs, ... }:
{
  flake-file.inputs.graphify = {
    url = "github:Graphify-Labs/graphify";
    flake = false;
  };

  den.aspects.applications.dev.ai.graphify = {
    homeManager =
      { pkgs, ... }:
      let
        graphifyPkg = pkgs.python3Packages.buildPythonApplication {
          pname = "graphifyy";
          version = "0.9.49";
          src = inputs.graphify;
          format = "pyproject";
          nativeBuildInputs = [ pkgs.python3Packages.setuptools ];
          propagatedBuildInputs = with pkgs.python3Packages; [
            networkx
            numpy
            rapidfuzz
            tree-sitter
            mcp
            starlette
          ];
          dontCheckRuntimeDeps = true;
          doCheck = false;
        };
      in
      {
        home.packages = [ graphifyPkg ];

        programs.claude-code = {
          mcpServers.graphify = {
            type = "stdio";
            command = "${graphifyPkg}/bin/graphify-mcp";
          };

          skills.graphify = "${inputs.graphify}/graphify";

          settings.permissions.allow = [
            "Bash(graphify *)"
            "Bash(graphify-mcp *)"
          ];
        };

        programs.git.ignores = [
          "/graphify-out/"
          ".graphifyignore"
        ];
      };
  };
}
