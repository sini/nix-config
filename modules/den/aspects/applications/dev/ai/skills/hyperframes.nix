# hyperframes (github:heygen-com/hyperframes): HTML video composition framework
# for AI coding agents. Provides all published HyperFrames skills and the
# `hyperframes` CLI binary with FFmpeg and Node.js.
{ inputs, ... }:
{
  flake-file.inputs.hyperframes = {
    url = "github:heygen-com/hyperframes";
    flake = false;
  };

  den.aspects.applications.dev.ai.skills.hyperframes = {
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

        hyperframesSubSkills = discoverDirectorySkills "${inputs.hyperframes}/skills";
      in
      {
        type = "plugin";
        marketplace = {
          name = "hyperframes";
          src = inputs.hyperframes;
          pluginId = "hyperframes@hyperframes";
        };
        skills = {
          hyperframes = "${inputs.hyperframes}/skills/hyperframes";
        }
        // hyperframesSubSkills;
      };

    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.local.hyperframes
          pkgs.ffmpeg-headless.bin
          pkgs.nodejs_22
        ];

        programs.claude-code = {
          settings.permissions.allow = [
            "Bash(hyperframes *)"
            "Bash(hyperframes-localize-fonts *)"
          ];
        };

        programs.git.ignores = [
          ".hyperframes/"
        ];
      };
  };
}
