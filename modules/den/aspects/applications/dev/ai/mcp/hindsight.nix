# hindsight (github:vectorize-io/hindsight): agent memory over the `den-law`
# bank — the fleet's standing operating law, stored verbatim.
#
# REMOTE MCP, not a local process: the server runs in the axon cluster and is
# reached over the private LoadBalancer, so this declares a `url` rather than a
# `command`. claude.nix routes url-bearing servers to the http transport.
#
# WRITE POSTURE. The standing ruling from the 2026-08-28 evaluation is that
# curation is the write path's property: auto-capturing adversarial transcripts
# would bank seeded defects and self-assessment prose as law. New law enters by
# the owner editing a memory file.
#
# That posture has two halves. Both are now held; only one is held HERE.
#
#   HELD HERE — the upstream claude-code plugin ships a Stop hook that retains
#   the transcript; it is deliberately NOT installed and no retain path is
#   wired. Measured against the active generation: settings.json carries six
#   other hook types and no Stop, so that absence is a real absence and not a
#   bad query.
#
#   HELD ON THE BANK, NOT HERE — `mcp_enabled_tools` was null, and null means
#   ALL, so `retain`, `update_bank`, `clear_memories` and `delete_bank` were
#   every bit as reachable as `recall`. Narrowed to the 15 read tools by hand on
#   2026-08-31, verified through a FRESH MCP session rather than the PATCH's
#   status code: 36 tools exposed before, 15 after. Read-only is now a property
#   rather than a posture — but nothing in this tree asserts it, and no rebuild
#   would restore it if someone set it back. See the note below on why it is not
#   declared here.
#
#   Prose could never have held that line: the `retain` tool's own description
#   opens "Use this tool PROACTIVELY whenever the user shares:", which the agent
#   reads at the moment of decision, while the skill's do-not-retain rule sits a
#   document away. The bank's audit log is also off, so a write that does happen
#   leaves no trace to find afterwards.
#
# Retaining the memory files is NOT mechanised. No unit in this tree does it —
# an earlier revision of this comment credited an "uplink sync unit" that does
# not exist — so it is an agent run by hand, and the bank's contents are
# therefore only as reviewed as that run was.
#
# BANK CONFIGURATION IS NOT MANAGED FROM HERE, and that is deliberate. Missions,
# dispositions, the observation switch and the tool allowlist are properties of
# the BANK — one shared object in the cluster. This aspect is a CONSUMER of that
# bank and ships to every dev host, so applying config from here would make
# three hosts writers on one resource, and hosts on different generations would
# flap the bank's configuration on each boot with the losing write silent.
# Built, measured and rejected on 2026-08-31 for that reason. If it is worth
# declaring, it belongs beside the service in
# aspects/kubernetes/services/ai/hindsight.nix, under exactly one writer.
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

          O3 must include a run under LOAD, not just a quiet one. Measured
          2026-08-31 during a backfill: recall exceeded 20s and the dataplane
          then refused connections for 135s. The script fails open, so the cost
          of that is not a broken session — it is up to 17s of dead time per
          prompt (2 health + 5 stats + 10 recall) followed by silence, which is
          indistinguishable from a bank that had nothing to say.
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

            # Partition on fact type. A `world` fact is the owner's text as
            # authored; an `observation` is the engine's synthesis OF that text.
            # Both earn their place, they are NOT the same kind of claim, and so
            # they never share a header — an observation printed under "Standing
            # law" is a paraphrase wearing the primary's label, which is the one
            # thing this bank exists to prevent.
            #
            # The cap is [0:20] on RESULTS. It used to be `head -20` on LINES,
            # and memory bodies run to dozens of lines each, so a single long
            # first hit consumed the whole budget and every later memory was
            # dropped with nothing to say so.
            out=$(printf '%s' "$resp" | ${jq} -r --arg bank "$bank" '
              (.results // [])[0:20] as $r
              | [$r[] | select(.type != "observation") | "- " + (.text // empty)] as $law
              | [$r[] | select(.type == "observation") | "- " + (.text // empty)] as $obs
              | (if ($law | length) > 0
                 then ["## Standing law (recalled from \($bank))", ""] + $law
                 else [] end)
                + (if ($obs | length) > 0
                   then ["", "## Observed patterns (synthesised from this bank — NOT owner law)", ""] + $obs
                   else [] end)
              | .[]
            ' 2>/dev/null)
            [ -z "$out" ] && exit 0

            printf '%s\n' "$out"
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
