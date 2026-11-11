"""Self-check for agent-quota: fake agy, codex and claude sources, run it end to end."""

import json
import os
import subprocess
import sys
import tempfile
import time

tool = sys.argv[1]

AGY = (
    "Gemini Models\tWeekly Limit Remaining\t14%\t2026-11-13T23:58:35Z\n"
    "Gemini Models\tFive Hour Limit Remaining\t81%\t2026-11-11T06:04:34Z\n"
    "Claude and GPT models\tWeekly Limit Remaining\t43%\t2026-11-12T01:52:22Z\n"
    "Claude and GPT models\tFive Hour Limit Remaining\t100%\t2026-11-11T08:39:09Z\n"
)
LIMITS = {
    "limit_id": "codex",
    "primary": {"used_percent": 68.0, "window_minutes": 10080, "resets_at": 1794514173},
    "secondary": {"used_percent": 25.5, "window_minutes": 300, "resets_at": 1794500000},
    "plan_type": "pro",
}
NOW_MS = int(time.time() * 1000)
CLAUDE_LIMITS = [
    {
        "kind": "weekly_all",
        "group": "weekly",
        "percent": 60,
        "resets_at": "2026-11-13T00:59:59.584709+00:00",
        "scope": None,
    },
    {
        "kind": "weekly_scoped",
        "group": "weekly",
        "percent": 0,
        "resets_at": "2026-11-13T01:00:00+00:00",
        "scope": {"model": {"id": None, "display_name": "Fable"}, "surface": None},
    },
    {"kind": "session", "group": "five_hour", "percent": 9, "resets_at": "x"},
]


def claude_json(limits, fetched_ms=NOW_MS - 90 * 60 * 1000):
    return {
        "numStartups": 3,
        "cachedUsageUtilization": {
            "fetchedAtMs": fetched_ms,
            "utilization": {"five_hour": None, "limits": limits},
        },
    }


def event(limits):
    return json.dumps(
        {
            "type": "event_msg",
            "payload": {"type": "token_count", "rate_limits": limits},
        },
        separators=(",", ":"),
    )


def run(t, agy_out, sessions, claude=None):
    bindir = os.path.join(t, "bin")
    os.makedirs(bindir, exist_ok=True)
    if agy_out is not None:
        with open(os.path.join(bindir, "agy"), "w") as f:
            f.write(f"#!{sys.executable}\nimport sys\nsys.stdout.write({agy_out!r})\n")
        os.chmod(os.path.join(bindir, "agy"), 0o755)
    home = os.path.join(t, "codex")
    for name, lines in sessions.items():
        p = os.path.join(home, "sessions", "2026", "11", "10", name)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w") as f:
            f.write("\n".join(lines) + "\n")
    if claude is not None:
        with open(os.path.join(t, ".claude.json"), "w") as f:
            json.dump(claude, f)
    # a source checkout's shebang needs python3; link only it, never its directory's agy
    if not os.path.exists(os.path.join(bindir, "python3")):
        os.symlink(sys.executable, os.path.join(bindir, "python3"))
    env = {"PATH": bindir, "CODEX_HOME": home, "HOME": t}
    out = subprocess.run(
        [tool, "--json"],
        env=env,
        capture_output=True,
        text=True,
        check=True,
    )
    text = subprocess.run(
        [tool], env=env, capture_output=True, text=True, check=True
    ).stdout
    return json.loads(out.stdout), text


def pick(rows, agent):
    return [
        (r["bucket"], r["window"], r["remaining_pct"], r["reset"])
        for r in rows
        if r["agent"] == agent
    ]


# All sources present; an older rollout and an earlier event in the newest file are
# ignored, and only weekly windows (agy: the Gemini Models bucket) are printed.
with tempfile.TemporaryDirectory() as t:
    older = dict(LIMITS, primary=dict(LIMITS["primary"], used_percent=1.0))
    rows, text = run(
        t,
        AGY,
        {
            "rollout-new.jsonl": [
                '{"type":"session_meta"}',
                event(older),
                event(LIMITS),
                "{}",
            ]
        },
        claude_json(CLAUDE_LIMITS),
    )
    assert pick(rows, "agy") == [
        ("Gemini Models", "Weekly", 14.0, "2026-11-13T23:58:35Z"),
    ], rows
    assert pick(rows, "codex") == [
        ("codex", "Weekly", 32.0, "2026-11-12T20:09:33Z"),
    ], rows
    assert pick(rows, "claude") == [
        ("All models", "Weekly", 40.0, "2026-11-13T00:59:59Z"),
        ("Fable", "Weekly", 100.0, "2026-11-13T01:00:00Z"),
    ], rows
    codex_rows = [r for r in rows if r["agent"] == "codex"]
    assert all(
        r["source"].startswith("rollout-new.jsonl (") and "old)" in r["source"]
        for r in codex_rows
    )
    claude_rows = [r for r in rows if r["agent"] == "claude"]
    assert all(
        r["source"] == "~/.claude.json cachedUsageUtilization (1h old)"
        for r in claude_rows
    ), claude_rows
    assert "Five Hour" not in text and "Claude and GPT" not in text, text
    assert (
        "agy\tGemini Models\tWeekly\t14%\t2026-11-13T23:58:35Z\tagy -p /quota" in text
    ), text
    assert (
        "claude\tAll models\tWeekly\t40%\t2026-11-13T00:59:59Z\t"
        "~/.claude.json cachedUsageUtilization (1h old)" in text
    ), text

# Missing sources: no agy on PATH, no codex sessions, no ~/.claude.json.
with tempfile.TemporaryDirectory() as t:
    rows, text = run(t, None, {})
    for agent in ("agy", "codex", "claude"):
        assert pick(rows, agent) == [("unknown", "unknown", None, None)], rows
    assert text.count("unknown") >= 12, text

# A ~/.claude.json without the usage cache is unknown, never a guess.
with tempfile.TemporaryDirectory() as t:
    rows, _ = run(t, None, {}, {"numStartups": 3})
    assert pick(rows, "claude") == [("unknown", "unknown", None, None)], rows

# An agy reply without a Gemini weekly line is unknown, not another bucket.
with tempfile.TemporaryDirectory() as t:
    rows, _ = run(t, "".join(AGY.splitlines(True)[1:]), {})
    assert pick(rows, "agy") == [("unknown", "unknown", None, None)], rows

# Garbled entries: only the garbled bucket goes unknown.
with tempfile.TemporaryDirectory() as t:
    garbled_agy = AGY.replace("14%", "fourteen%").replace("43%", "forty%")
    garbled_codex = dict(
        LIMITS,
        primary=dict(LIMITS["primary"], used_percent="x"),
        secondary={"used_percent": 1, "window_minutes": "x", "resets_at": 1},
    )
    garbled_claude = [dict(CLAUDE_LIMITS[0], percent="x")] + CLAUDE_LIMITS[1:]
    rows, _ = run(
        t,
        garbled_agy,
        {"rollout-a.jsonl": [event(garbled_codex)]},
        claude_json(garbled_claude),
    )
    assert pick(rows, "agy") == [("Gemini Models", "Weekly", None, None)], rows
    assert pick(rows, "codex") == [
        ("codex", "Weekly", None, None),
        ("codex", "unknown", None, None),
    ], rows
    assert pick(rows, "claude") == [
        ("All models", "Weekly", None, None),
        ("Fable", "Weekly", 100.0, "2026-11-13T01:00:00Z"),
    ], rows

# A rollout whose last rate_limits line is truncated JSON is unknown, not an older reading.
with tempfile.TemporaryDirectory() as t:
    rows, _ = run(t, AGY, {"rollout-b.jsonl": [event(LIMITS), event(LIMITS)[:-20]]})
    assert pick(rows, "codex") == [("unknown", "unknown", None, None)], rows

print("agent-quota self-test: ok")
