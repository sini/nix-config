# ponytail (github:dietrichgebert/ponytail): Lazy senior dev mode for AI agents.
# Ships a store-pinned plugin containing native activation and subagent hooks.
{ inputs, ... }:
{
  flake-file.inputs.ponytail = {
    url = "github:dietrichgebert/ponytail";
    flake = false;
  };

  den.aspects.applications.dev.ai.ponytail = {
    homeManager =
      { ... }:
      {
        programs.claude-code = {
          marketplaces.ponytail = inputs.ponytail;
          settings.enabledPlugins."ponytail@ponytail" = true;
        };
      };
  };
}
