# hindsight (github:vectorize-io/hindsight): agent memory over the `den-law`
# bank — the fleet's standing operating law, stored verbatim.
#
# REMOTE MCP, not a local process: the server runs in the axon cluster and is
# reached over the private LoadBalancer, so this declares a `url` rather than a
# `command`. claude.nix routes url-bearing servers to the http transport.
#
# WRITE POSTURE IS READ-ONLY BY CONSTRUCTION. The upstream claude-code plugin
# ships a Stop hook that retains the transcript; it is deliberately NOT
# installed, and this aspect wires no retain path at all. That is the standing
# ruling from the 2026-08-28 evaluation: curation is the write path's property,
# and auto-capturing adversarial transcripts would bank seeded defects and
# self-assessment prose as law. New law enters by the owner editing a memory
# file, which the uplink sync unit retains.
{ lib, ... }:
{
  den.aspects.applications.dev.ai.mcp.hindsight = {
    settings = {
      endpoint = lib.mkOption {
        type = lib.types.str;
        default = "http://10.11.0.20:8888";
        description = ''
          Base URL of the hindsight dataplane API. Defaults to the axon
          cluster's private LoadBalancer address, reserved as
          `hindsight-internal` in that cluster's kubernetes-loadbalancers
          network — BGP-advertised to the LAN and not internet-routable. An IP
          rather than a name because the service has no HTTPRoute and therefore
          no service domain; give it one and this becomes a hostname.
        '';
      };

      bank = lib.mkOption {
        type = lib.types.str;
        default = "den-law";
        description = ''
          Bank to expose. hindsight serves one MCP endpoint per bank at
          `/mcp/<bank>/`, so this selects what the agent can see. Transcript- or
          session-derived memory belongs in a DIFFERENT bank; pointing this at
          one would put retired records and unreviewed self-assessment in front
          of the agent as law.
        '';
      };

      recallHook = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Install a UserPromptSubmit hook that recalls from the bank on every
          prompt and injects the results as context.

          Default false. This is a READ path — it cannot write to the bank — but
          it changes every prompt in every session, so it is opt-in and wants
          evidence first: the replay oracle (O3) green before it is worth
          paying for on each turn. The MCP tools above already make recall
          available on demand; this only removes the need to ask.
        '';
      };
    };

    agent-extensions =
      { host, ... }:
      let
        cfg = host.settings.applications.dev.ai.mcp.hindsight;
      in
      {
        type = "mcp";
        mcpServers.hindsight = {
          # Trailing slash matters: upstream serves the per-bank endpoint at
          # `/mcp/<bank>/` and a request without it does not route.
          url = "${cfg.endpoint}/mcp/${cfg.bank}/";
        };
        skills.hindsight = ./_skills/hindsight;
      };

    homeManager =
      {
        host,
        config,
        pkgs,
        lib,
        ...
      }:
      let
        cfg = host.settings.applications.dev.ai.mcp.hindsight;
        jq = lib.getExe pkgs.jq;
        curl = lib.getExe pkgs.curl;
        recall = "${config.home.homeDirectory}/.claude/hindsight-recall.sh";
      in
      {
        # Recall helper. Written unconditionally so it can be run by hand for a
        # replay check; only WIRED as a hook when recallHook is enabled.
        home.file.".claude/hindsight-recall.sh" = {
          executable = true;
          text = ''
            #!/usr/bin/env bash
            # Recall standing law relevant to a prompt. Reads the hook payload on
            # stdin, emits recalled text on stdout for injection as context.
            #
            # Fails OPEN at every step: a memory service that is down must never
            # block a session, so all failure paths exit 0 with no output and
            # stderr is never allowed to leak into the agent's context.
            set -uo pipefail
            base="${cfg.endpoint}"
            bank="${cfg.bank}"

            # Preflight, cheapest first. Without these a cold or empty bank costs
            # a full recall round-trip on every prompt and injects a header with
            # nothing under it.
            ${curl} -sS -m 2 -o /dev/null "$base/health" 2>/dev/null || exit 0
            nodes=$(${curl} -sS -m 5 "$base/v1/default/banks/$bank/stats" 2>/dev/null \
              | ${jq} -r '.total_nodes // 0' 2>/dev/null) || exit 0
            [ "''${nodes:-0}" -gt 0 ] 2>/dev/null || exit 0

            payload=$(cat 2>/dev/null || true)
            # hooks-reference documents `prompt`, but some claude-code builds
            # emit `user_prompt`; upstream's own hook accepts both, so do we.
            prompt=$(printf '%s' "$payload" \
              | ${jq} -r '(.prompt // .user_prompt) // empty' 2>/dev/null || true)
            # Sub-5-char prompts ("ok", "yes") carry no retrieval signal and
            # would inject arbitrary law against a meaningless query.
            [ "''${#prompt}" -lt 5 ] && exit 0

            # Two filters, both load-bearing for a LAW bank:
            #   tags   — `archived` memories are retired records; serving them as
            #            current policy is the failure that tag exists to prevent.
            #   min_scores — a weak semantic match injected as "standing law" is
            #            worse than injecting nothing, because the agent cannot
            #            tell a 0.09 match from a 1.10 one once it is in context.
            body=$(${jq} -nc --arg q "$prompt" \
              '{query:$q, tags:["active"], tags_match:"any", budget:"low",
                min_scores:{reranker:0.5}}' 2>/dev/null) || exit 0

            resp=$(${curl} -sS -m 10 -X POST \
              "$base/v1/default/banks/$bank/memories/recall" \
              -H 'Content-Type: application/json' -d "$body" 2>/dev/null) || exit 0

            memories=$(printf '%s' "$resp" \
              | ${jq} -r '(.results // [])[]? | "- " + (.text // empty)' 2>/dev/null | head -20)
            [ -z "$memories" ] && exit 0

            echo "## Standing law (recalled from $bank)"
            echo ""
            echo "$memories"
            exit 0
          '';
        };

        programs.claude-code.settings = lib.mkIf cfg.recallHook {
          hooks.UserPromptSubmit = [
            {
              hooks = [
                {
                  type = "command";
                  command = "bash ${recall} || true";
                }
              ];
            }
          ];
        };
      };
  };
}
