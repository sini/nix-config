# beads (github:gastownhall/beads): an AI-supervised issue tracker for coding
# agents. Its own aspect in the codebase-memory-mcp mold — installs the `bd`
# binary and wires the Claude Code integration in one place. beads ships a
# first-class CC plugin (skill + slash commands + `bd prime` SessionStart/
# PreCompact hooks), so rather than hand-replicate that we register its upstream
# marketplace store-pinned and enable the plugin. It is skill/hook-based, not an
# MCP server, so it lives beside the other ai tool aspects rather than under mcp/.
{ inputs, ... }:
{
  flake-file.inputs.beads = {
    url = "github:gastownhall/beads";
    inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  den.aspects.apps.dev.ai.beads = {
    homeManager =
      { inputs', ... }:
      {
        # `bd` must be on PATH: the plugin's SessionStart/PreCompact hooks run
        # `bd prime`, and the slash commands shell out to it.
        home.packages = [ inputs'.beads.packages.default ];

        programs.claude-code = {
          # Store-pinned marketplace: CC resolves the plugin from the nix store
          # (inputs.beads = the flake source, which holds .claude-plugin/
          # marketplace.json), not by fetching GitHub at runtime.
          marketplaces.beads-marketplace = inputs.beads;
          settings.enabledPlugins."beads@beads-marketplace" = true;
        };
      };
  };
}
