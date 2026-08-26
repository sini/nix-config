# one-skill-to-rule-them-all (github:rebelytics/one-skill-to-rule-them-all): Task observer skill.
{ inputs, ... }:
{
  flake-file.inputs.one-skill-to-rule-them-all = {
    url = "github:rebelytics/one-skill-to-rule-them-all";
    flake = false;
  };

  den.aspects.applications.dev.ai.skills.one-skill-to-rule-them-all = {
    agent-extensions = {
      type = "skill";
      skills = {
        task-observer = inputs.one-skill-to-rule-them-all;
      };
    };
  };
}
