# one-skill-to-rule-them-all (github:rebelytics/one-skill-to-rule-them-all):
# Task Observer meta-skill that monitors work, identifies new skill candidates,
# and logs improvements.
{ inputs, ... }:
{
  flake-file.inputs.one-skill-to-rule-them-all = {
    url = "github:rebelytics/one-skill-to-rule-them-all";
    flake = false;
  };

  den.aspects.applications.dev.ai.skills.one-skill-to-rule-them-all = {
    homeManager =
      { ... }:
      {
        programs.claude-code.skills.task-observer = "${inputs.one-skill-to-rule-them-all}";
      };
  };
}
