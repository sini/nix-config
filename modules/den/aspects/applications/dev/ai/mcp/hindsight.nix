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
# ★ THAT RULING WAS AMENDED (owner, 2026-09-01): session capture is ADMITTED, to
# ONE bank, segmented by a `tier:` tag rather than by a second bank. The ground
# it rested on is unchanged and is now carried by the tier and the strategy
# instead of by exclusion — an episode is EVIDENCE and says so, law is the
# owner's to write, and the two are separable at recall (`tag_groups` takes
# AND/OR/NOT, verified against this bank by result identity, not by count).
# A second bank was considered and rejected in the same sitting: the mission
# attaches to the WRITE PATH, which a named retain strategy already gives, and
# splitting the store would prevent cross-tier consolidation.
#
#   HELD HERE — upstream's plugin hooks Stop and carries a retain cursor; this
#   deployment installs neither. `archiveHook` below is the equivalent path, on
#   SessionEnd rather than Stop, ON since 2026-09-01, and reasoned out with the
#   evidence that turned it on at that option.
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
          `/mcp/<bank>/`, so this selects what the agent can see.

          ONE bank holds every tier, owner-ruled 2026-09-01. What keeps retired
          records and session evidence from reading as law is the `tier:` tag,
          not a separate store: every document carries one, derived from its
          ORIGIN rather than judged — `specs/adr/` layout for the ADR corpus,
          each memory file's own frontmatter `type:` for the rest. Backfilled
          across 253 documents on that basis, which put `tier:law` on 39 of
          them, not on the 224 a tag-reading heuristic had proposed.
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
          of that is not a broken session — it is dead time per prompt followed
          by silence, which is indistinguishable from a bank that had nothing
          to say.

          THE BUDGET IS NOW 75s WORST CASE (5 health + 10 stats + 60 recall),
          up from 17s. Not padding: hindsight's own server trace on 2026-09-01
          shows one recall at 24.128s, of which 24.036s is the CROSS-ENCODER
          scoring 289 candidates to return five. Retrieval was 0.029s. The old
          10s recall budget sat BELOW that floor, so under load it would time
          out every time — spending 10s to inject nothing, the worst of both.
          This makes the ceiling honest rather than making it fast, and it is
          precisely why this hook stays off until O3 measures what 75s per
          prompt actually costs.

          The number moves as the bank grows: candidates scale with the corpus,
          reranking scales with candidates, and session capture adds corpus.
        '';
      };

      archiveHook = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Install a SessionEnd hook that renders the session transcript and
          retains it as `tier:episode`.

          On since 2026-09-01. It was opt-in until the bank's `episode` strategy
          was settled, because a mission that extracts the wrong thing writes
          sediment into the same bank recall serves law from. What discharged
          that, in order:

            · the strategy NAME resolves. Armed pair, same content, same call:
              `episode` returned extracted prose, a deliberately bogus name
              returned THE RAW JSONL as one verbatim fact at HTTP 200. Upstream
              falls back on an unknown name with only a server-side log line, so
              a typo here banks unextracted transcripts and reports success.
            · one real 5.8 MB session, end to end: 28 facts, 0 unlabelled,
              19 measurement / 5 correction / 4 instrument, every fact carrying
              tier: project: session: and kind:.
            · attribution holds. The corrections name "Peer message" and "the
              scout" rather than the owner — which is the renderer's peer
              re-labelling working, and is the whole reason it exists.

          SessionEnd, not Stop. Upstream's plugin hooks Stop and carries a
          retain cursor to go with it, because Stop fires every time the agent
          finishes responding — without a cursor that re-extracts the whole
          transcript on every turn, at LLM cost, against a growing session.
          Archival wants one firing per session, so it hooks the event that
          gives exactly that.

          The cost of SessionEnd is a session that dies without firing it, which
          is never captured. That is covered by construction rather than by
          hoping: `document_id` is the session id, so the disk sweep over
          `~/.claude/projects/**` and this hook are the same write, and either
          one may run twice or in either order.
        '';
      };

      episodeStrategy = lib.mkOption {
        type = lib.types.str;
        default = "episode";
        description = ''
          Name of the bank's retain strategy for session transcripts.

          Named once, here, because an unknown strategy name FAILS SILENTLY:
          upstream's `apply_strategy` logs a warning and returns the resolved
          config unchanged (`config_resolver.py`, "Unknown retain strategy
          '<name>', using resolved config as-is"). A typo therefore does not
          error — it retains the transcript under the bank's DEFAULT mission,
          which is the law mission, whose closing instruction is to ignore
          session narration. The result is a retain that reports success and
          banks almost nothing.
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
        archive = "${config.home.homeDirectory}/.claude/hindsight-archive.sh";
        renderer = "${config.home.homeDirectory}/.claude/hindsight-episode.jq";
      in
      {
        # Backfill tool for sessions that predate the hook, or that ended without
        # firing it. Overridden with THIS host's endpoint and bank rather than
        # carrying its own copy of them — the package's defaults exist so it runs
        # standalone, not so there are two places to change the address.
        home.packages = [
          (pkgs.local.hindsight-backfill.override {
            inherit (cfg) endpoint bank;
          })
        ];

        # Transcript renderer, shared by the SessionEnd hook and the disk sweep so
        # both produce the SAME shape — a corpus assembled by two renderers is two
        # corpora. Derived from upstream's `transcript.ts`, which this deployment
        # does not install; the rules it encodes are theirs, the two divergences
        # below are ours and are measured.
        #
        # Keeps the ENGINEERING SUBSTANCE: requests, narration, and one compact
        # `action` turn per tool call naming the tool and its target. Drops
        # tool_result (outputs are mechanical noise), thinking, isMeta/isSidechain
        # lines, and Claude Code's own compaction summary — that last one arrives
        # as a plain type:"user" record with no flag but isCompactSummary, and it
        # recaps turns already retained, so keeping it extracts them twice.
        #
        # Measured on one 5.8 MB session: 2223 lines -> 643 turns, 386 KB (15x).
        # Across 90 sessions: 810 MB -> 11.6 MB (70x). Control in the same run:
        # 372 tool_use blocks in, 372 action turns out, on a FROZEN copy — the
        # live file is appended to while it is read, and two counts of the same
        # predicate minutes apart differ for that reason alone.
        #
        # DIVERGENCE 1 — <system-reminder> is load-bearing here, not insurance.
        # Upstream strips it against the day it moves; on this fleet it CARRIES
        # CLAUDE.md and the memory index, so leaving it in feeds the bank its own
        # injected context. Measured: 6 occurrences in, 0 out, with real content
        # surviving in the same run.
        #
        # DIVERGENCE 2 — a peer session's message arrives as type:"user".
        # Measured on one session: 30 of 72 user turns (42%) are other sessions
        # writing through <teammate-message>, so the extractor reads them as the
        # OWNER speaking. Their content is substantive, so they are re-labelled
        # rather than dropped. Left as "user" they become owner testimony, and
        # that false attribution then lives INSIDE the fact's own text, where no
        # tag filter and no tier can reach it.
        home.file.".claude/hindsight-episode.jq".text = ''
          def strip_injected:
            gsub("<(hook_prompt|task-notification|system-reminder|local-command-stdout|command-name|command-message|command-args|hindsight_memories|hindsight_bank|relevant_memories)\\b[\\s\\S]*?</(hook_prompt|task-notification|system-reminder|local-command-stdout|command-name|command-message|command-args|hindsight_memories|hindsight_bank|relevant_memories)>"; "");

          def action_line:
            . as $b
            | ($b.input // {}) as $i
            | ( [ $i.file_path?, $i.path?, $i.notebook_path?, $i.command?, $i.pattern?, $i.query?, $i.url?, $i.name?, $i.id? ]
                | map(select(type == "string" and (. | gsub("^\\s+|\\s+$"; "")) != ""))
                | first ) as $t
            | if $t == null then $b.name
              else ($t | split("\n")[0] | .[0:100]) as $s | "\($b.name) \($s)"
              end;

          select(.type == "user" or .type == "assistant")
          | select(.isMeta != true and .isSidechain != true and .isCompactSummary != true)
          | select(.message | type == "object")
          | . as $line
          | ($line.message.content) as $c
          | ( if ($c | type) == "string" then
                [ { role: $line.type, content: ($c | strip_injected) } ]
              elif ($c | type) == "array" then
                ( [ $c[] | select(type == "object" and .type == "text" and (.text | type) == "string")
                    | .text | strip_injected ]
                  | map(select(gsub("^\\s+|\\s+$"; "") != ""))
                  | join("\n") ) as $prose
                | ( if ($prose | gsub("^\\s+|\\s+$"; "")) != "" then [ { role: $line.type, content: $prose } ] else [] end )
                  + [ $c[] | select(type == "object" and .type == "tool_use" and (.name | type) == "string")
                      | { role: "action", content: action_line } ]
              else [] end ) as $turns
          | $turns[]
          | select((.content | gsub("^\\s+|\\s+$"; "")) != "")
          | .content |= gsub("^\\s+|\\s+$"; "")
          | if .role == "user" and (.content | test("<teammate-message")) then .role = "peer" else . end
          | if ($line.timestamp | type) == "string" then . + { timestamp: $line.timestamp } else . end
        '';

        # Session archiver. Written unconditionally so the disk sweep can call it
        # by hand; only WIRED as a hook when archiveHook is enabled.
        home.file.".claude/hindsight-archive.sh" = {
          executable = true;
          text = ''
            #!/usr/bin/env bash
            # Render this session's transcript and retain it as tier:episode.
            #
            # Fails OPEN at every step, like the recall path: a memory service that
            # is down must never delay or break a session close.
            #
            # Usage: as a SessionEnd hook (payload on stdin), or by hand for the
            # disk sweep:
            #   hindsight-archive.sh <transcript.jsonl> [session_id] [project]
            #
            # The sweep passes `project` rather than letting it be derived, because
            # a transcript on disk sits under Claude Code's MUNGED directory name
            # (`-home-sini-Documents-repos-sini-den-ag-design`) and un-munging it is
            # not decidable: `-` is both the path separator and a character inside
            # `den-ag-design`. The hook path has no such problem — `cwd` arrives in
            # the payload as a real path.
            set -uo pipefail
            base="${cfg.endpoint}"
            bank="${cfg.bank}"
            strategy="${cfg.episodeStrategy}"

            # ★ FAIL OPEN, BUT LEAVE A TRACE. Exiting 0 on every error is required —
            # a memory service that is down must not delay a session close — and it
            # is also what makes "never fired" and "fired and banked nothing" look
            # identical from outside. They are different defects with different
            # fixes, so each bail names its stage. This is the only reason the ARG_MAX
            # bug below would have been findable had it shipped.
            log="$HOME/.claude/hindsight-archive.log"
            fail() { printf '%s\t%s\t%s\n' "$(date -Is)" "''${session:-?}" "$1" >> "$log"; exit 0; }

            # ★★★ UNCONDITIONAL FIRING LINE, BEFORE ANY BAIL. Without it "the hook NEVER
            # FIRED" and "the hook FIRED AND DID NOTHING" are indistinguishable, and this
            # script had THREE silent exits — unreadable transcript, empty session id, and a
            # render under 400 bytes — none of which touched the log. Measured 2026-09-02:
            # the owner exited and resumed, and afterwards the bail log held only a stale
            # entry, the session's document was unchanged, and no operation had been queued.
            # That is consistent with the hook never running AND with it running against a
            # payload lacking transcript_path or session_id, which are different defects.
            # SessionEnd's payload fields are UNMEASURED — claude.nix documents SessionStart,
            # SubagentStart and SubagentStop, deliberately not this one — so the guess is not
            # idle. This line is what turns the next session close into evidence.
            printf '%s\tFIRED\targv=%s\n' "$(date -Is)" "$#" >> "$log"

            if [ $# -ge 1 ]; then
              transcript="$1"
              session="''${2:-$(basename "$transcript" .jsonl)}"
              cwd="$(dirname "$transcript")"
            else
              payload=$(cat 2>/dev/null || true)
              transcript=$(printf '%s' "$payload" | ${jq} -r '.transcript_path // empty' 2>/dev/null || true)
              session=$(printf '%s' "$payload" | ${jq} -r '.session_id // empty' 2>/dev/null || true)
              cwd=$(printf '%s' "$payload" | ${jq} -r '.cwd // empty' 2>/dev/null || true)
            fi
            # These two exits were SILENT and are the most likely place a real SessionEnd
            # firing disappears — a payload without transcript_path or session_id looks
            # exactly like a hook that never ran.
            [ -r "''${transcript:-}" ] || fail "no-transcript:''${transcript:-EMPTY}"
            [ -n "''${session:-}" ] || fail "no-session-id"

            # `project:` records where the work HAPPENED, never what it was about.
            # It localises the wrong-working-directory class: a measurement taken in
            # the wrong tree reads as authoritative unless something says where it
            # was taken.
            project="''${3:-$(basename "''${cwd:-unknown}")}"
            case "$project" in ""|.|/|-*) project="unknown" ;; esac

            ${curl} -sS -m 2 -o /dev/null "$base/health" 2>/dev/null || fail "health"

            # ★★ EVERYTHING GOES THROUGH FILES, NEVER THROUGH ARGV OR A SHELL VAR.
            # A rendered session is ~386 KB and one line of a 5.8 MB transcript can
            # be 16 KB; `--arg c "$turns"` and `curl -d "$body"` BOTH exceed ARG_MAX
            # and die with "argument list too long". Measured 2026-09-01 against the
            # real transcript before this path ever ran live. It is the worst shape
            # of failure available here: the script still exits 0, the hook reports
            # success, and NOTHING is ever banked — on every session, because every
            # real session clears the limit. `--rawfile` and `-d @file` are why the
            # size stops mattering.
            turns=$(mktemp) || exit 0
            req=$(mktemp) || { rm -f "$turns"; exit 0; }
            trap 'rm -f "$turns" "$req"' EXIT

            ${jq} -c -f "${renderer}" "$transcript" > "$turns" 2>/dev/null || fail "render"
            # A session that rendered to almost nothing has nothing to extract, and
            # a retain against it still costs a full LLM pass per chunk.
            [ "$(wc -c < "$turns")" -lt 400 ] && exit 0

            # document_id is the SESSION id and update_mode is replace, so this is
            # idempotent: the SessionEnd hook and the disk sweep are the same write,
            # and running either twice replaces rather than duplicates.
            # The HOOK wants fire-and-forget: a session close must not wait on 30
            # chunks of extraction. The BACKFILL wants the opposite — one session
            # at a time, so progress is observable, an interrupt loses at most one
            # session, and 90 of them do not land on the queue at once. Same write
            # path, one switch.
            async=true
            [ "''${HINDSIGHT_ARCHIVE_SYNC:-0}" = "1" ] && async=false

            ${jq} -nc --rawfile c "$turns" --argjson async "$async" \
              --arg s "$session" --arg p "$project" --arg st "$strategy" \
              '{async: $async, items: [{
                  content: $c,
                  context: "One agent working session, rendered transcript.",
                  document_id: $s,
                  update_mode: "replace",
                  strategy: $st,
                  tags: ["tier:episode", ("project:" + $p), ("session:" + $s)]
                }]}' > "$req" 2>/dev/null || fail "build"

            # The timeout follows the mode. Async returns as soon as the retain is
            # ACCEPTED, so 30s is generous. Sync returns when EXTRACTION FINISHES,
            # and one real 5.8 MB session measured ~10 minutes across ~30 chunks —
            # 30s there would abort every session and log a "post" bail that looks
            # like the service is down.
            timeout=30
            [ "$async" = "false" ] && timeout=3600

            ${curl} -sS -m "$timeout" -X POST "$base/v1/default/banks/$bank/memories" \
              -H 'Content-Type: application/json' --data-binary @"$req" \
              >/dev/null 2>&1 || fail "post"
            exit 0
          '';
        };

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
            ${curl} -sS -m 5 -o /dev/null "$base/health" 2>/dev/null || exit 0
            nodes=$(${curl} -sS -m 10 "$base/v1/default/banks/$bank/stats" 2>/dev/null \
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

            resp=$(${curl} -sS -m 60 -X POST \
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

        # Every hook that talks to this bank, in one place — READ on prompt, READ on
        # subagent start, WRITE on session end. They were split across claude.nix and
        # here, which put the recall query, the tags it filters on, and the tier those
        # tags are written by in two files that had to be changed together.
        #
        # Three arms, three gates, deliberately different: UserPromptSubmit is opt-in
        # and OFF (a per-prompt cost on an unmet evidence bar), SessionEnd is opt-in
        # and ON (the write path, with the evidence recorded at its option), and
        # SubagentStart is UNCONDITIONAL — it is a read, it costs nothing against an
        # empty bank, and an agent dispatched without its standing law is the failure
        # this aspect exists to prevent.
        #
        # Hook LISTS merge across modules: codebase-memory-mcp.nix contributes its own
        # SubagentStart command arm and the two combine rather than conflict. Verified
        # when this moved — the evaluated hook set is byte-identical either side, which
        # is also what caught the move landing on a bare `SubagentStart` instead of
        # `hooks.SubagentStart`: it evaluated clean and silently dropped all four.
        programs.claude-code.settings = lib.mkMerge [
          (lib.mkIf cfg.recallHook {
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
          })
          {
            # ★★★ A SUBAGENT IS STARTING — RECALL INTO ITS OWN CONTEXT, BEFORE ITS FIRST PROMPT.
            # This is the beat the orchestrator cannot cover: by the time it dispatches, the
            # brief is already written, so a recall there informs nobody in time and never
            # reaches the agent. `SubagentStart` injects into the SUBAGENT's context
            # (docs, hooks#subagentstart) and is the only event that does.
            # ★★ WHY A HOOK AND NOT AN INSTRUCTION: the agents hold `recall` themselves, and an
            # instruction to use it is exactly what was measured to fail — 0 recalls across 14
            # dispatches in one session, with the instruction sitting in context the whole time.
            # A rule that depends on remembering has now failed twice, measured. This makes it
            # mechanical.
            # ★ THE MATCHER IS THE AGENT TYPE, which is what lets each role recall on its OWN
            # subject with no payload interpolation — the payload carries only `agent_id` and
            # `agent_type`, never the task prompt, so a per-role query is the available
            # granularity. The agent refines from there with its own `recall`.
            # ★ `mcp_tool` is permitted here and carries none of SessionStart's "MCP not yet
            # connected" caveat, which makes this a better host for an MCP-backed recall.
            # ★★ VERIFY BEFORE TRUSTING IT — this event fails silently in two ways (see the
            # PreToolUse block). Read a SUBAGENT's transcript, never the parent's, and confirm
            # the recalled text is present before its first tool call. If the mcp_tool handler
            # does not fire, the command arm below still delivers the instruction, so the floor
            # is the pre-existing behaviour rather than nothing.
            # ★★ THE 90s TIMEOUT IS MEASURED, NOT PADDING. From hindsight's OWN server trace
            # on 2026-09-01, not from a client stopwatch:
            #     [2] parallel retrieval          0.029s  -> 289 candidates
            #     [4] reranking [cross-encoder]  24.036s  -> 289 scored
            #     total                          24.128s
            # Recall latency is the CROSS-ENCODER, not the LLM and not the network: the
            # reranker scores every candidate to return five. The first version allowed 20s,
            # which under that load did not merely risk failing — it failed EVERY time.
            # ★ And it fails toward SILENCE. A timed-out recall leaves the agent starting with
            # no standing law and nothing to say so, which is the defect this block exists to
            # remove. A slow dispatch beats a quiet one.
            # ★ It gets SLOWER AS THE BANK GROWS — candidates scale with the corpus and the
            # reranker scales with candidates, so session capture moves this number. Re-read
            # the SERVER trace before trusting 90; a client stopwatch cannot separate rerank
            # time from queue wait, and under a backfill it is nearly all queue wait.
            hooks.SubagentStart = [
              {
                matcher = "gen-scout";
                hooks = [
                  {
                    type = "mcp_tool";
                    server = "plugin_hm_hindsight";
                    tool = "recall";
                    input = {
                      query = "measurement law, absence claims and live controls, grep and predicate traps, tool behaviours that lie, burned control tokens, shell idioms that fail silently";
                      tags = [
                        "tier:law"
                        "tier:trap"
                        "role:scout"
                      ];
                      tags_match = "any_strict";
                    };
                    timeout = 90;
                  }
                ];
              }
              {
                matcher = "gen-gate";
                hooks = [
                  {
                    type = "mcp_tool";
                    server = "plugin_hm_hindsight";
                    tool = "recall";
                    input = {
                      query = "adversarial gate rubric, prior art sweeps, refutation discipline, second independent pass, coordinate and citation checking";
                      tags = [
                        "tier:law"
                        "tier:trap"
                        "role:gate"
                      ];
                      tags_match = "any_strict";
                    };
                    timeout = 90;
                  }
                ];
              }
              {
                matcher = "gen-spec";
                hooks = [
                  {
                    type = "mcp_tool";
                    server = "plugin_hm_hindsight";
                    tool = "recall";
                    input = {
                      query = "spec form and acceptance oracles, ADR law and amendment policy, owner rulings, forks that must not be settled by an agent";
                      tags = [
                        "tier:law"
                        "tier:trap"
                        "role:spec"
                      ];
                      tags_match = "any_strict";
                    };
                    timeout = 90;
                  }
                ];
              }
              {
                matcher = "gen-build";
                hooks = [
                  {
                    type = "mcp_tool";
                    server = "plugin_hm_hindsight";
                    tool = "recall";
                    input = {
                      query = "landing and commit discipline, formatting before commit, nix-unit and oracle arming, seeded defects, push gates";
                      tags = [
                        "tier:law"
                        "tier:trap"
                        "role:build"
                      ];
                      tags_match = "any_strict";
                    };
                    timeout = 90;
                  }
                ];
              }
            ];
          }
          (lib.mkIf cfg.archiveHook {
            hooks.SessionEnd = [
              {
                hooks = [
                  {
                    type = "command";
                    # Rendering is local and cheap; the retain is `async: true`, so
                    # the request returns once accepted rather than once extracted.
                    command = "bash ${archive} || true";
                    timeout = 60;
                  }
                ];
              }
            ];
          })
        ];
      };
  };
}
