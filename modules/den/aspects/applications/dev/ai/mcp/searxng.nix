# searxng MCP: the fleet's SearXNG (kubernetes/services/ai/searxng.nix) as a search
# tool for every harness that takes MCP servers through agent-extensions — claude,
# agy and opencode.
#
# Server: nixpkgs `mcp-searxng` (github:ihor-sokoliuk/mcp-searxng), a stdio server
# over SearXNG's JSON API. Taken from nixpkgs rather than written here: it is the
# widely used one, nixpkgs packages and maintains it, and it is configured by
# environment alone.
#
# Tools: searxng_web_search, searxng_search_suggestions, searxng_instance_info,
# web_url_read. Only the first three are pre-allowed in claude. web_url_read fetches
# an arbitrary URL, which each harness already does through its own fetch tool with
# its own policy, so it stays on that harness's prompt rather than a second, quieter
# path. agy keeps its settings mutable (antigravity-cli.nix) and opencode admits MCP
# tools by default, so neither needs an entry.
#
# pi is not covered: it takes TypeScript extensions, not MCP servers (pi.nix).
#
# Gating check: searxng-check.nix, over each harness's rendered config.
{ lib, ... }:
{
  den.aspects.applications.dev.ai.mcp.searxng = {
    settings.endpoint = lib.mkOption {
      type = lib.types.str;
      default = "http://10.11.0.24:8080";
      description = ''
        Base URL of the fleet's SearXNG. Defaults to the axon cluster's
        `searxng-internal` LoadBalancer address, BGP-advertised to the LAN and not
        internet-routable; search.<domain> is the OIDC-gated UI, which a headless
        client cannot pass.
      '';
    };

    agent-extensions =
      {
        host,
        lib,
        pkgs,
        ...
      }:
      {
        type = "mcp";
        mcpServers.searxng = {
          command = lib.getExe pkgs.mcp-searxng;
          env.SEARXNG_URL = host.settings.applications.dev.ai.mcp.searxng.endpoint;
        };
      };

    homeManager = {
      programs.claude-code.settings.permissions.allow = map (t: "mcp__plugin_hm_searxng__${t}") [
        "searxng_web_search"
        "searxng_search_suggestions"
        "searxng_instance_info"
      ];
    };
  };
}
