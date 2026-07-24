# The claude-code toolchain (binaries). Pulls in `claude-config` (settings + the
# .claude state map) — den merges quirks across files but NOT a class function, so
# the config's `homeManager` lives in its own aspect rather than a second
# `claude.homeManager` here (which would last-wins-clobber this one). replicate.nix
# adds the replicated dir set onto `claude` directly (a quirk, so it merges).
{ den, ... }:
{
  flake-file.inputs.codebase-memory-mcp.url = "github:kriswill/codebase-memory-mcp/nix";

  den.aspects.apps.dev.ai.mcp.codebase-memory = {
    homeManager =
      { pkgs, inputs', ... }:
      {
        home.packages = with pkgs; [
          codebase-memory-mcp
        ];
        programs.mcp.servers."codebase-memory-mcp" = {
          enabled = true;
          command = "${lib.getExe pkgs.codebase-memory-mcp}";
          type = "local";
        };

        programs.git.ignores = [
          "/AGENTS.md"
          ".cbmignore"
        ];
      };
  };
}
