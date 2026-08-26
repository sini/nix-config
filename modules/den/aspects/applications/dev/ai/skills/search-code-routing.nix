# search-code-routing: Structural code search routing across `ast-grep` (AST tree shape)
# and `ripgrep` (literal regex).
{
  den.aspects.applications.dev.ai.skills.search-code-routing = {
    agent-extensions = {
      type = "skill";
      skills = {
        search-code-routing = ./assets/search-code-routing;
      };
    };

    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.ast-grep
          pkgs.ripgrep
        ];
      };
  };
}
