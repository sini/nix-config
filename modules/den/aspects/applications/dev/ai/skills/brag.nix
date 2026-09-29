# brag (github:latent-spaces/brag): Turn projects and websites into short,
# shareable launch videos using Hyperframes or lean Opus 5.5 workflow.
{ den, inputs, ... }:
{
  flake-file.inputs.brag = {
    url = "github:latent-spaces/brag";
    flake = false;
  };

  den.aspects.applications.dev.ai.skills.brag = {
    includes = [
      den.aspects.applications.dev.ai.skills.hyperframes
    ];

    agent-extensions = {
      type = "plugin";
      marketplace = {
        name = "brag";
        src = inputs.brag;
        pluginId = "brag@brag";
      };
      skills = {
        brag = "${inputs.brag}/skills/brag";
        brag-slim = "${inputs.brag}/skills/brag-slim";
      };
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
          ];
        };

        programs.git.ignores = [
          "brag-output*/"
        ];
      };
  };
}
