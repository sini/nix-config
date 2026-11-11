"""Self-check for agent-quota: fake agy, codex and claude sources, run it end to end."""

import hashlib
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


def run(t, agy_out, sessions, claude=None, agy_log=None):
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
    if agy_log is not None:
        logdir = os.path.join(t, ".gemini", "antigravity-cli", "log")
        os.makedirs(logdir, exist_ok=True)
        with open(os.path.join(logdir, "cli-20261111_000000.log"), "w") as f:
            f.write(agy_log)
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
    plain = subprocess.run([tool], env=env, capture_output=True, text=True, check=True)
    global everything
    everything = out.stdout + out.stderr + plain.stdout + plain.stderr
    return json.loads(out.stdout), plain.stdout


def sha12(raw):
    return hashlib.sha256(raw.encode()).hexdigest()[:12]


def accounts(rows):
    return {a: {r["account"] for r in rows if r["agent"] == a} for a in AGENTS}


AGENTS = ("agy", "codex", "claude")


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
    # age_s is a number agreeing with the age in the text source
    for r in rows:
        assert type(r["age_s"]) is int, r
    assert all(5400 <= r["age_s"] < 5460 for r in claude_rows), claude_rows
    assert all(
        0 <= r["age_s"] < 60 and f"({r['age_s']}s old)" in r["source"]
        for r in codex_rows
    ), codex_rows
    assert [r["age_s"] for r in rows if r["agent"] == "agy"] == [0], rows
    # no ID recorded anywhere: unknown
    assert all(r["account"] == "unknown" for r in rows), rows

# Missing sources: no agy on PATH, no codex sessions, no ~/.claude.json.
with tempfile.TemporaryDirectory() as t:
    rows, text = run(t, None, {})
    for agent in ("agy", "codex", "claude"):
        assert pick(rows, agent) == [("unknown", "unknown", None, None)], rows
    assert all(r["account"] == "unknown" and r["age_s"] is None for r in rows), rows
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

# Account hashes. Canary: every fixture we read plants an email and a token next to the
# ID; neither may surface anywhere, while the ID's hash must (so the fixture IS read).
EMAIL, TOKEN = "canary@example.invalid", "canary-token-XYZ"


def account_run(codex_id, claude_id, agy_email):
    meta = {
        "type": "session_meta",
        "payload": {
            "id": "s1",
            "creator_account_id": codex_id,
            "creator_user_id": "user-" + TOKEN,
            "email": EMAIL,
            "access_token": TOKEN,
        },
    }
    claude = claude_json(CLAUDE_LIMITS)
    claude["oauthAccount"] = {
        "accountUuid": claude_id,
        "emailAddress": EMAIL,
        "displayName": TOKEN,
    }
    claude["primaryApiKey"] = TOKEN
    log = (
        f"I1111 applyAuthResult: email={agy_email}, authMethod=consumer, quotaProject=\n"
        f"I1111 refresh: access_token={TOKEN} id_token={TOKEN} user={EMAIL}\n"
    )
    with tempfile.TemporaryDirectory() as t:
        rows, _ = run(
            t,
            AGY,
            {"rollout-c.jsonl": [json.dumps(meta), event(LIMITS)]},
            claude,
            log,
        )
    for canary in (EMAIL, TOKEN, "canary", codex_id, claude_id):
        assert canary not in everything, canary
    assert agy_email not in everything, agy_email
    return rows


ID_A, ID_B = "acct-0000-aaaa", "acct-0000-bbbb"
rows_a = account_run(ID_A, ID_A, "a@agy.invalid")
assert accounts(rows_a) == {
    "agy": {sha12("a@agy.invalid")},
    "codex": {sha12(ID_A)},
    "claude": {sha12(ID_A)},
}, rows_a
rows_a2 = account_run(ID_A, ID_B, "b@agy.invalid")
assert accounts(rows_a2)["codex"] == accounts(rows_a)["codex"], (
    rows_a2
)  # same ID, same hash
assert accounts(rows_a2)["claude"] != accounts(rows_a)["claude"], (
    rows_a2
)  # different ID
assert accounts(rows_a2)["agy"] != accounts(rows_a)["agy"], rows_a2
assert all(len(r["account"]) == 12 for r in rows_a2), rows_a2

# The field missing (or empty) beside an otherwise good source is unknown.
with tempfile.TemporaryDirectory() as t:
    claude = claude_json(CLAUDE_LIMITS)
    claude["oauthAccount"] = {"emailAddress": EMAIL}
    rows, _ = run(
        t,
        AGY,
        {
            "rollout-d.jsonl": [
                '{"type":"session_meta","payload":{"creator_account_id":""}}',
                event(LIMITS),
            ]
        },
        claude,
        "I1111 applyAuthResult: email=, authMethod=consumer\n",
    )
    assert all(r["account"] == "unknown" for r in rows), rows
    assert pick(rows, "codex") == [("codex", "Weekly", 32.0, "2026-11-12T20:09:33Z")], (
        rows
    )
    assert EMAIL not in everything

print("agent-quota self-test: ok")
