# gstack (github:garrytan/gstack): Garry's Stack — Claude Code skills + fast
# headless browser + QA / CEO / review / autoplan / cso slash commands.
{ inputs, ... }:
{
  flake-file.inputs.gstack = {
    url = "github:garrytan/gstack";
    flake = false;
  };

  den.aspects.applications.dev.ai.skills.gstack = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.bun ];

        programs.claude-code = {
          skills.gstack = "${inputs.gstack}";

          settings.permissions.allow = [
            "Bash(~/.claude/skills/gstack/*)"
            "Bash(bun run *)"
          ];
        };

        programs.git.ignores = [
          ".gstack/"
        ];
      };
  };
}
