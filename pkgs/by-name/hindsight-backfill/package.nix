{
  writeShellApplication,
  jq,
  curl,
  coreutils,
  findutils,
  endpoint ? "http://10.11.0.20:8888",
  bank ? "den-law",
}:
# Publish past Claude Code sessions to the hindsight bank as `tier:episode`.
#
# The SessionEnd hook captures sessions from now on; this captures the ones that
# already happened. It deliberately does NOT re-implement the write — it invokes
# the same `hindsight-archive.sh` the hook does, so the corpus is assembled by one
# renderer and one retain path. Two renderers would give two corpora.
#
# RESUMABLE WITHOUT LOCAL STATE. The bank is the source of truth: `document_id` is
# the session id, so the set of finished sessions is a query, not a file. A run that
# is interrupted, a host that is rebuilt, and a second host publishing at the same
# time all behave correctly, because nothing depends on a cursor anyone has to keep.
# The cost is one list call per run.
#
# WHY IT RUNS PER HOST. Transcripts live under the user's own ~/.claude/projects, so
# sibling hosts publish their own; the aspect ships this to each. Session ids are
# uuids, so two hosts cannot collide, and `--projects-dir` covers the other shape —
# a directory copied over from a host that cannot reach the endpoint.
writeShellApplication {
  name = "hindsight-backfill";
  meta.description = "Publish past Claude Code sessions to a hindsight bank as tier:episode";
  runtimeInputs = [
    jq
    curl
    coreutils
    findutils
  ];
  text = ''
    set -uo pipefail

    base="''${HINDSIGHT_ENDPOINT:-${endpoint}}"
    bank="''${HINDSIGHT_BANK:-${bank}}"
    archiver="''${HINDSIGHT_ARCHIVER:-$HOME/.claude/hindsight-archive.sh}"
    projects="$HOME/.claude/projects"
    dry=0
    force=0
    limit=0
    sleep_between=0

    usage() {
      cat <<'USAGE'
    hindsight-backfill [options]

      --projects-dir DIR   where session transcripts live (default ~/.claude/projects)
      --limit N            publish at most N sessions this run
      --sleep S            seconds to wait between sessions
      --force              republish sessions the bank already holds
      --dry-run            list what would be published, write nothing
      -h, --help           this

    Resumable: sessions already in the bank are skipped, so re-running after an
    interrupt continues where it stopped. Nothing is kept on disk to go stale.
    USAGE
    }

    while [ $# -gt 0 ]; do
      case "$1" in
        --projects-dir) projects="$2"; shift 2 ;;
        --limit) limit="$2"; shift 2 ;;
        --sleep) sleep_between="$2"; shift 2 ;;
        --force) force=1; shift ;;
        --dry-run) dry=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
      esac
    done

    [ -d "$projects" ] || { echo "no such projects dir: $projects" >&2; exit 1; }
    [ -x "$archiver" ] || [ -r "$archiver" ] || {
      echo "archiver not found: $archiver" >&2; exit 1; }

    # ★ REFUSE AN ARCHIVER THAT CANNOT DO SYNC. Measured 2026-09-01: run against an
    # older deployed archiver, every retain went out ASYNC, all 90 sessions hit the
    # queue in 10 seconds, and the fact-count check then read 0 for each because
    # extraction had not started — so the tool reported "empty 90" while actually
    # having launched the whole backfill uncontrolled. It looked like a total
    # failure and was the opposite. A version check is the difference between one
    # session at a time and flooding the fleet's only inference instance.
    grep -q 'HINDSIGHT_ARCHIVE_SYNC' "$archiver" || {
      echo "archiver at $archiver has no sync mode — it would submit every session" >&2
      echo "asynchronously at once. Deploy the current hindsight aspect first." >&2
      exit 1; }

    # Fail LOUD, unlike the hook. A hook that cannot reach the bank must not break a
    # session close; a backfill that cannot reach it has nothing to do and should say
    # so, rather than walk 90 sessions reporting each one skipped.
    curl -sS -m 5 -o /dev/null "$base/health" || {
      echo "hindsight unreachable at $base" >&2; exit 1; }

    # Resumability, in one call: the ids the bank already holds.
    done_ids=$(curl -sS -m 60 "$base/v1/default/banks/$bank/documents?limit=100000" \
      | jq -r '(.items // [])[].id // empty' | sort -u) || {
      echo "could not list documents from $base/$bank" >&2; exit 1; }
    echo "bank holds $(printf '%s' "$done_ids" | grep -c . || true) document(s)"

    # Depth 2 only: <projects>/<munged-cwd>/<session>.jsonl. Subagent transcripts sit
    # a level deeper under <session>/subagents/ and are a DIFFERENT shape — every line
    # is isSidechain, which the renderer drops, so they would render to zero turns and
    # be silently skipped. They are out of scope here rather than accidentally empty.
    mapfile -t files < <(find "$projects" -mindepth 2 -maxdepth 2 -name '*.jsonl' | sort)
    echo "found ''${#files[@]} session transcript(s) under $projects"

    published=0 skipped=0 failed=0 empty=0 attempted=0
    for f in "''${files[@]}"; do
      session=$(basename "$f" .jsonl)

      if [ "$force" -eq 0 ] && printf '%s\n' "$done_ids" | grep -qxF "$session"; then
        skipped=$((skipped + 1))
        continue
      fi
      # Bound ATTEMPTS, not successes. Counting only successes means a run of
      # empty or failed sessions never trips the limit and walks the whole corpus.
      if [ "$limit" -gt 0 ] && [ "$attempted" -ge "$limit" ]; then
        break
      fi
      attempted=$((attempted + 1))

      # The project comes from the TRANSCRIPT'S OWN cwd, never from the directory
      # name: Claude Code munges the path into that name by replacing / with -, and
      # un-munging is undecidable because - is also a character inside a repo name
      # like den-ag-design. The shortest cwd a session recorded is its root; deeper
      # ones are subdirectories it visited.
      # `|| true` is load-bearing, not defensive noise. writeShellApplication runs
      # this under `set -euo pipefail`, and one malformed line makes jq exit
      # non-zero, which under pipefail fails the pipeline and under errexit ENDS
      # THE WHOLE RUN — silently, mid-corpus, with a zero exit status. Measured:
      # a first version stopped after 8 of 90 sessions and reported nothing wrong.
      project=$(jq -r 'select(.cwd) | .cwd' "$f" 2>/dev/null \
        | awk '{ print length, $0 }' | sort -n | head -1 | cut -d' ' -f2- \
        | xargs -r basename 2>/dev/null || true)
      [ -n "''${project:-}" ] || project="unknown"

      size=$(wc -c < "$f")
      if [ "$dry" -eq 1 ]; then
        printf 'WOULD PUBLISH  %-40s project=%-20s %8d bytes\n' "$session" "$project" "$size"
        published=$((published + 1))
        continue
      fi

      printf 'publishing     %-40s project=%-20s %8d bytes ... ' "$session" "$project" "$size"
      start=$(date +%s)
      # SYNC: return when extraction finishes, not when the retain is accepted. One
      # session at a time keeps progress observable, bounds an interrupt to a single
      # session, and keeps 90 of them off the queue at once.
      if HINDSIGHT_ARCHIVE_SYNC=1 bash "$archiver" "$f" "$session" "$project"; then
        elapsed=$(( $(date +%s) - start ))
        n=$(curl -sS -m 30 "$base/v1/default/banks/$bank/memories/list?document_id=$session&limit=500" \
          | jq -r '(.items // []) | length' 2>/dev/null || echo 0)
        if [ "''${n:-0}" -gt 0 ]; then
          printf 'ok  %s fact(s)  %ss\n' "$n" "$elapsed"
          published=$((published + 1))
        else
          # The archiver exits 0 when a session renders to almost nothing, so a
          # zero here is "nothing worth extracting", not a failure — but it is
          # counted separately, because a run that is ALL zeroes means the renderer
          # or the strategy broke, and a bare success count would hide that.
          printf 'empty  %ss\n' "$elapsed"
          empty=$((empty + 1))
        fi
      else
        printf 'FAILED\n'
        failed=$((failed + 1))
      fi

      # `if`, not `[ … ] && sleep`: as the last statement in the loop body under
      # errexit, an && list that evaluates false is a non-zero exit status and
      # takes the script with it — so the default of no sleep would have ended
      # the run after the first session.
      if [ "$sleep_between" -gt 0 ]; then sleep "$sleep_between"; fi
    done

    echo
    echo "published $published · empty $empty · already-present $skipped · failed $failed"
    [ "$failed" -eq 0 ]
  '';
}
