{
  lib,
  writeShellApplication,
  jq,
  gnugrep,
  curl,
  coreutils,
  git,
  endpoint ? "http://10.11.0.20:8888",
  bank ? "den-law",
  repos ? [ ],
}:
# Bring the hindsight bank's handoff documents current with git history.
#
# A handoff (`STATUS/HANDOFF.md`) cannot reach the bank through the session path:
# the transcript renderer compacts a tool call to `<Tool> <target>`, and a handoff's
# text exists only as a Write argument. So every revision is retained from git.
#
# A RECONCILER, NOT A REGISTRATION STEP. The work is derived on every run from
# `git log -- STATUS/HANDOFF.md` against what the bank holds; `document_id` is
# `handoff-<first 12 of the commit sha>`, so the set of finished revisions is a
# query, and a re-run publishes nothing. A skipped close, or a session that died
# before writing one, is picked up next time — a per-handoff step loses whatever it
# misses, permanently and silently.
#
# ★ PRESENT IS NOT COMPLETE. Measured 2026-09-02: 89 revisions retained with
# "failed 0", and 28 of them held ZERO facts. So a held document with no facts, or
# with materially fewer chunks than its text implies (hindsight-backfill's 80%
# floor), is counted and named on every run. It is REPAIRED only under --repair,
# by DELETE then retain: `update_mode: replace` no-ops on byte-identical content,
# and a handoff revision's content never changes. Not automatic, because some
# early, thin handoffs legitimately extract to nothing and would re-extract on
# every run.
writeShellApplication {
  name = "hindsight-handoff-reconcile";
  meta.description = "Retain every git revision of STATUS/HANDOFF.md the hindsight bank does not yet hold";
  runtimeInputs = [
    jq
    curl
    coreutils
    gnugrep
    git
  ];
  text = ''
    set -uo pipefail

    base="''${HINDSIGHT_ENDPOINT:-${endpoint}}"
    bank="''${HINDSIGHT_BANK:-${bank}}"
    strategy="''${HINDSIGHT_HANDOFF_STRATEGY:-handoff}"
    file="STATUS/HANDOFF.md"
    context="A session handoff: the curated record of what one working session settled."
    repo_list=(${lib.escapeShellArgs repos})
    dry=0
    repair=0
    limit=0

    usage() {
      cat <<'USAGE'
    hindsight-handoff-reconcile [options] [--repo DIR]...

      --repo DIR     a git repository carrying STATUS/HANDOFF.md (repeatable;
                     replaces the configured list)
      --limit N      publish at most N revisions this run
      --repair       delete-then-retain held documents that are empty or incomplete
      --dry-run      list what would be published or repaired, write nothing
      -h, --help     this

    Idempotent: a revision the bank holds as handoff-<sha12> is not re-sent.
    USAGE
    }

    given=()
    while [ $# -gt 0 ]; do
      case "$1" in
        --repo) given+=("$2"); shift 2 ;;
        --limit) limit="$2"; shift 2 ;;
        --repair) repair=1; shift ;;
        --dry-run) dry=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
      esac
    done
    [ "''${#given[@]}" -gt 0 ] && repo_list=("''${given[@]}")
    [ "''${#repo_list[@]}" -gt 0 ] || { echo "no repository given and none configured" >&2; exit 2; }

    doclist=$(mktemp); held=$(mktemp); body=$(mktemp); req=$(mktemp)
    resp=$(mktemp); delresp=$(mktemp)
    trap 'rm -f "$doclist" "$held" "$body" "$req" "$resp" "$delresp"' EXIT

    # Fail LOUD on anything that would make "nothing to do" and "could not look"
    # the same answer. Unlike the archiver this is not on a session's close path —
    # the hook only starts it — so a refusal costs nothing but a journal line.
    curl -sS -m 5 -o /dev/null "$base/health" || {
      echo "hindsight unreachable at $base" >&2; exit 1; }
    curl -sS -f -m 60 "$base/v1/default/banks/$bank/documents?limit=100000" -o "$doclist" || {
      echo "could not list documents from $base/$bank" >&2; exit 1; }
    # The envelope key is checked, not defaulted: this API uses `items` here and
    # `operations` elsewhere, and a `.items // []` read of the wrong one is a clean 0.
    jq -e '.items | type == "array"' "$doclist" >/dev/null || {
      echo "document list from $base/$bank has no .items array" >&2; exit 1; }
    jq -r '.items[] | select(.id | startswith("handoff-"))
           | "\(.id)\t\(.memory_unit_count // 0)"' "$doclist" > "$held"
    echo "bank holds $(wc -l < "$held") handoff document(s)"

    # The strategy must EXIST on the bank. An unknown name falls back silently to the
    # bank default at HTTP 200 (the law mission, which extracts nearly nothing from
    # a handoff), and a mistyped bank is auto-created empty and reads as "all 224
    # revisions missing". Both are refused here rather than published into.
    chunk_size=$(curl -sS -f -m 30 "$base/v1/default/banks/$bank/config" \
      | jq -er --arg s "$strategy" '.config.retain_strategies[$s]
          | select(. != null) | .retain_chunk_size // 12000') || {
      echo "bank $bank has no retain strategy '$strategy'" >&2; exit 1; }

    fact_count() {
      curl -sS -f -m 30 "$base/v1/default/banks/$bank/memories/list?document_id=$1&limit=500" \
        | jq -er '.items | arrays | length'
    }

    publish() { # id sha date project
      pub_detail=""
      git -C "$top" show "$2:$file" > "$body" || {
        pub_detail="could not read $2:$file"; return 1; }
      jq -nc --rawfile c "$body" --arg id "$1" --arg ts "$3" --arg p "$4" \
        --arg st "$strategy" --arg cx "$context" \
        '{async: false, items: [{
            content: $c, context: $cx, document_id: $id, timestamp: $ts,
            update_mode: "replace", strategy: $st,
            tags: ["subject:handoff", "tier:episode", ("project:" + $p)]
          }]}' > "$req" || { pub_detail="could not build request"; return 1; }
      # SYNC and serial: one revision at a time keeps 135 of them off the queue at
      # once — the 2026-09-01 flood was every retain submitted async together.
      # The response is captured, not sent to /dev/null: a 2xx carrying an
      # unparseable body or an explicit success:false would otherwise pass as
      # ok. operation_id is documented null on this path (every call here is
      # async:false; the API only populates it for async: true), so it is
      # still extracted and printed for the day that changes, but the one
      # per-call detail synchronous retain actually returns is `usage`
      # (LLM token counts) — extracted here because that response body is
      # the only place it exists at all.
      code=$(curl -sS -m 3600 -o "$resp" -w '%{http_code}' -X POST \
        "$base/v1/default/banks/$bank/memories" \
        -H 'Content-Type: application/json' --data-binary @"$req") || {
        pub_detail="transport error"; return 1; }
      case "$code" in
        2??) ;;
        *) pub_detail="HTTP $code $(tr -s '[:space:]' ' ' < "$resp" | head -c 200)"
           return 1 ;;
      esac
      jq -e '.success == true' "$resp" >/dev/null 2>&1 || {
        pub_detail="unparseable or success:false response: $(tr -s '[:space:]' ' ' < "$resp" | head -c 200)"
        return 1; }
      pub_op=$(jq -r '.operation_id // "-"' "$resp")
      pub_tok=$(jq -r '.usage.total_tokens // "-"' "$resp")
    }

    published=0 empty=0 present=0 held_empty=0 incomplete=0 repaired=0 failed=0 attempted=0
    for repo in "''${repo_list[@]}"; do
      top=$(git -C "$repo" rev-parse --show-toplevel) || {
        echo "not a git repository: $repo" >&2; failed=$((failed + 1)); continue; }
      project=$(basename "$top")
      revs=$(git -C "$top" log --format='%H %cI' -- "$file") || {
        echo "git log failed in $top" >&2; failed=$((failed + 1)); continue; }
      echo "$top: $(printf '%s' "$revs" | grep -c .) revision(s) of $file"

      while read -r sha date; do
        [ -n "$sha" ] || continue
        # A commit that deletes the file is a revision of its path with no body.
        git -C "$top" cat-file -e "$sha:$file" 2>/dev/null || continue
        id="handoff-''${sha:0:12}"
        mode=publish
        row=$(grep -m1 "^$id"$'\t' "$held" || true)
        if [ -n "$row" ]; then
          have=''${row#*$'\t'}
          if [ "$have" -eq 0 ]; then
            state=EMPTY
          else
            bytes=$(git -C "$top" cat-file -s "$sha:$file")
            want=$(( (bytes + chunk_size - 1) / chunk_size ))
            floor=$(( want * 8 / 10 ))
            state=ok
            if [ "$floor" -gt 0 ]; then
              chunks=$(curl -sS -f -m 30 "$base/v1/default/banks/$bank/documents/$id/chunks?limit=1" \
                | jq -er '.total | numbers') || chunks=""
              if [ -z "$chunks" ]; then
                echo "could not read chunks for $id" >&2; failed=$((failed + 1)); continue
              fi
              [ "$chunks" -ge "$floor" ] || state=INCOMPLETE
            fi
          fi
          if [ "$state" = ok ]; then present=$((present + 1)); continue; fi
          [ "$state" = EMPTY ] && held_empty=$((held_empty + 1))
          [ "$state" = INCOMPLETE ] && incomplete=$((incomplete + 1))
          if [ "$repair" -eq 0 ]; then
            printf '%-12s %s  %s\n' "$state" "$id" "$date"
            continue
          fi
          mode=repair
        fi

        if [ "$limit" -gt 0 ] && [ "$attempted" -ge "$limit" ]; then break 2; fi
        attempted=$((attempted + 1))

        if [ "$dry" -eq 1 ]; then
          if [ "$mode" = repair ]; then
            printf 'WOULD REPAIR   %s  %s\n' "$id" "$date"; repaired=$((repaired + 1))
          else
            printf 'WOULD PUBLISH  %s  %s\n' "$id" "$date"; published=$((published + 1))
          fi
          continue
        fi

        printf '%-14s %s  %s ... ' "$mode" "$id" "$date"
        # del_units stays "-" for a plain publish (nothing was deleted); a repair
        # captures the delete response too, since memory_units_deleted is the
        # diagnostic that says whether the doc repair thought it was fixing
        # actually held anything.
        del_units="-"
        if [ "$mode" = repair ]; then
          delcode=$(curl -sS -m 60 -o "$delresp" -w '%{http_code}' -X DELETE \
            "$base/v1/default/banks/$bank/documents/$id") || {
            printf 'FAILED (delete: transport error)\n'; failed=$((failed + 1)); continue; }
          case "$delcode" in
            2??) del_units=$(jq -r '.memory_units_deleted // "-"' "$delresp" 2>/dev/null) || del_units="-" ;;
            *) printf 'FAILED (delete: HTTP %s %s)\n' "$delcode" \
                 "$(tr -s '[:space:]' ' ' < "$delresp" | head -c 200)"
               failed=$((failed + 1)); continue ;;
          esac
        fi
        if ! publish "$id" "$sha" "$date" "$project"; then
          printf 'FAILED (%s)\n' "$pub_detail"; failed=$((failed + 1)); continue
        fi
        n=$(fact_count "$id") || n=""
        if [ -z "$n" ]; then
          printf 'FAILED (fact count unreadable)\n'; failed=$((failed + 1))
        elif [ "$n" -gt 0 ]; then
          printf 'ok  %s fact(s)  [op=%s tok=%s del=%s]\n' "$n" "$pub_op" "$pub_tok" "$del_units"
          if [ "$mode" = repair ]; then repaired=$((repaired + 1)); else published=$((published + 1)); fi
        else
          printf 'empty  [op=%s tok=%s del=%s]\n' "$pub_op" "$pub_tok" "$del_units"
          empty=$((empty + 1))
        fi
      done <<< "$revs"
    done

    echo
    verb=""; [ "$dry" -eq 1 ] && verb="would-"
    echo "''${verb}publish $published · ''${verb}repair $repaired · empty $empty · already-present $present · held-empty $held_empty · incomplete $incomplete · failed $failed"
    [ "$failed" -eq 0 ]
  '';
}
