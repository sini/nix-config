# ponytail (github:dietrichgebert/ponytail): Agent harness companions.
{ inputs, ... }:
{
  flake-file.inputs.ponytail = {
    url = "github:dietrichgebert/ponytail";
    flake = false;
  };

  den.aspects.applications.dev.ai.skills.ponytail = {
    agent-extensions = {
      type = "plugin";
      marketplace = {
        name = "ponytail";
        src = inputs.ponytail;
        pluginId = "ponytail@ponytail";
      };
      skills = {
        ponytail = inputs.ponytail;
      };
    };
  };
}
