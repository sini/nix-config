"""Self-check for agent-quota: fake agy and codex sources, run the tool end to end."""

import json
import os
import subprocess
import sys
import tempfile

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


def event(limits):
    return json.dumps(
        {
            "type": "event_msg",
            "payload": {"type": "token_count", "rate_limits": limits},
        },
        separators=(",", ":"),
    )


def run(t, agy_out, sessions):
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


# Both sources present; an older rollout and an earlier event in the newest file are ignored.
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
    )
    assert pick(rows, "agy") == [
        ("Gemini Models", "Weekly", 14.0, "2026-11-13T23:58:35Z"),
        ("Gemini Models", "Five Hour", 81.0, "2026-11-11T06:04:34Z"),
        ("Claude and GPT models", "Weekly", 43.0, "2026-11-12T01:52:22Z"),
        ("Claude and GPT models", "Five Hour", 100.0, "2026-11-11T08:39:09Z"),
    ], rows
    assert pick(rows, "codex") == [
        ("codex", "Weekly", 32.0, "2026-11-12T20:09:33Z"),
        ("codex", "Five Hour", 74.5, "2026-11-12T16:13:20Z"),
    ], rows
    codex_rows = [r for r in rows if r["agent"] == "codex"]
    assert all(
        r["source"].startswith("rollout-new.jsonl (") and "old)" in r["source"]
        for r in codex_rows
    )
    assert (
        "agy\tGemini Models\tWeekly\t14%\t2026-11-13T23:58:35Z\tagy -p /quota" in text
    ), text

# Missing sources: no agy on PATH, no codex sessions.
with tempfile.TemporaryDirectory() as t:
    rows, text = run(t, None, {})
    assert pick(rows, "agy") == [("unknown", "unknown", None, None)], rows
    assert pick(rows, "codex") == [("unknown", "unknown", None, None)], rows
    assert text.count("unknown") >= 8, text

# Garbled lines: only the garbled bucket goes unknown.
with tempfile.TemporaryDirectory() as t:
    garbled_agy = AGY.replace("43%", "forty%")
    garbled_codex = dict(
        LIMITS, secondary={"used_percent": "x", "window_minutes": 300, "resets_at": 1}
    )
    rows, _ = run(t, garbled_agy, {"rollout-a.jsonl": [event(garbled_codex)]})
    agy_rows = pick(rows, "agy")
    assert agy_rows[2] == ("Claude and GPT models", "Weekly", None, None), agy_rows
    assert [r[2] for r in agy_rows] == [14.0, 81.0, None, 100.0], agy_rows
    assert pick(rows, "codex") == [
        ("codex", "Weekly", 32.0, "2026-11-12T20:09:33Z"),
        ("codex", "Five Hour", None, None),
    ], rows

# A rollout whose last rate_limits line is truncated JSON is unknown, not an older reading.
with tempfile.TemporaryDirectory() as t:
    rows, _ = run(t, AGY, {"rollout-b.jsonl": [event(LIMITS), event(LIMITS)[:-20]]})
    assert pick(rows, "codex") == [("unknown", "unknown", None, None)], rows

print("agent-quota self-test: ok")
