# gstack (github:garrytan/gstack): Garry Tan's suite of autonomous workflow skills
# for AI coding agents. Automatically discovers sub-skills (`browse`, `qa`, `make-pdf`,
# `design-review`, `health`, `context-save`, etc.) and provides bun runtime.
{ inputs, ... }:
{
  flake-file.inputs.gstack = {
    url = "github:garrytan/gstack";
    flake = false;
  };

  den.aspects.applications.dev.ai.skills.gstack = {
    agent-extensions =
      { lib, ... }:
      let
        discoverDirectorySkills =
          skillsDir:
          lib.mapAttrs' (name: _: lib.nameValuePair name "${skillsDir}/${name}") (
            lib.filterAttrs (
              name: type: type == "directory" && builtins.pathExists "${skillsDir}/${name}/SKILL.md"
            ) (builtins.readDir skillsDir)
          );

        gstackSubSkills = discoverDirectorySkills inputs.gstack;
      in
      {
        type = "skill";
        skills = {
          gstack = inputs.gstack;
        } // gstackSubSkills;
      };

    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.bun ];

        programs.claude-code = {
          settings.permissions.allow = [
            "Bash(bun run *)"
            "Bash(bun *)"
            "Bash(~/.claude/skills/*)"
          ];
        };

        programs.git.ignores = [
          ".gstack/"
        ];
      };
  };
}
