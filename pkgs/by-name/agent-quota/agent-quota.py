#!/usr/bin/env python3
"""Print the remaining weekly usage quota of the agy, codex and claude agents.

Read-only and credential-free: agy answers `agy -p /quota` locally without a model call
(its Gemini Models bucket only), codex's figures come from the rate_limits object its own
session rollouts record, and claude's from the cachedUsageUtilization field Claude Code
keeps in ~/.claude.json (the data /usage shows, stamped with its fetch time). Only weekly
windows are printed. No token or auth file is opened. A source that is missing or
unparseable prints unknown.

--json rows also carry `age_s` (the reading's age in seconds, null when there is no
reading) and `account`: the first 12 hex digits of the sha256 of the harness's account
ID, never the ID itself. The IDs come from non-credential files: codex's session_meta
creator_account_id in the same rollout, claude's oauthAccount.accountUuid in
~/.claude.json, and the email agy's own log records at sign-in (applyAuthResult).
"""

import argparse
import glob
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from datetime import UTC, datetime

UNKNOWN = "unknown"
WEEK_MINUTES = 10080
AGY_BUCKET = "Gemini Models"
AGY_SIGNIN = re.compile(r"applyAuthResult: email=([^,\s]+)")


def row(
    agent, bucket=UNKNOWN, window=UNKNOWN, remaining=None, reset=None, source=UNKNOWN
):
    return {
        "agent": agent,
        "bucket": bucket,
        "window": window,
        "remaining_pct": remaining,
        "reset": reset,
        "source": source,
    }


def account(raw):
    """Only a hash of the ID leaves this function; the raw value is never stored."""
    if not isinstance(raw, str) or not raw:
        return UNKNOWN
    return hashlib.sha256(raw.encode()).hexdigest()[:12]


def stamp(rows, acct, age_s):
    for r in rows:
        r["account"] = acct
        r["age_s"] = age_s
    return rows


def utc(ts):
    return datetime.fromtimestamp(ts, UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def age(seconds):
    seconds = int(max(seconds, 0))
    for unit, size in (("d", 86400), ("h", 3600), ("m", 60)):
        if seconds >= size:
            return f"{seconds // size}{unit}"
    return f"{seconds}s"


def parse_agy(text):
    """`<bucket>\\t<window> Limit Remaining\\t<pct>%\\t<RFC3339 reset>` per line."""
    rows = []
    for line in text.splitlines():
        if not line.strip():
            continue
        f = line.split("\t")
        r = row("agy", source="agy -p /quota")
        if len(f) >= 2 and f[0].strip() and f[1].strip():
            r["bucket"] = f[0].strip()
            r["window"] = f[1].strip().removesuffix(" Limit Remaining")
        try:
            if len(f) != 4 or not f[2].endswith("%"):
                raise ValueError(line)
            pct = float(f[2][:-1])
            reset = datetime.fromisoformat(f[3].strip())
            if reset.tzinfo is None or not 0 <= pct <= 100:
                raise ValueError(line)
            r["remaining_pct"] = pct
            r["reset"] = utc(reset.timestamp())
        except ValueError:
            pass
        if r["bucket"] == AGY_BUCKET and r["window"] == "Weekly":
            rows.append(r)
    return rows or [row("agy", source="agy -p /quota")]


def agy_account():
    """The sign-in email the newest agy log records, hashed; the token file is never read."""
    logs = glob.glob(os.path.expanduser("~/.gemini/antigravity-cli/log/*.log"))
    for log in sorted(logs, key=os.path.getmtime, reverse=True):
        found = None
        try:
            with open(log, encoding="utf-8", errors="replace") as f:
                for line in f:
                    m = AGY_SIGNIN.search(line)
                    if m:
                        found = m.group(1)
        except OSError:
            continue
        if found:
            return account(found)
    return UNKNOWN


def agy():
    acct = agy_account()
    with tempfile.TemporaryDirectory() as cwd:
        try:
            out = subprocess.run(
                ["agy", "-p", "/quota"],
                cwd=cwd,
                capture_output=True,
                text=True,
                timeout=60,
                stdin=subprocess.DEVNULL,
                check=False,
            )
        except (OSError, subprocess.TimeoutExpired):
            return stamp([row("agy")], acct, None)
    if out.returncode != 0:
        return stamp([row("agy")], acct, None)
    rows = parse_agy(out.stdout)
    return stamp(rows, acct, 0 if rows[0]["remaining_pct"] is not None else None)


def parse_codex_limits(limits, source):
    bucket = limits.get("limit_id") or UNKNOWN
    rows = []
    for key in ("primary", "secondary"):
        w = limits.get(key)
        if w is None:
            continue
        r = row("codex", bucket=bucket, source=source)
        try:
            minutes = int(w["window_minutes"])
        except (TypeError, KeyError, ValueError):
            rows.append(r)  # window unreadable: it may be the weekly one, so unknown
            continue
        if minutes != WEEK_MINUTES:
            continue
        r["window"] = "Weekly"
        try:
            used = float(w["used_percent"])
            if not 0 <= used <= 100:
                raise ValueError(used)
            r["remaining_pct"] = 100 - used
            r["reset"] = utc(int(w["resets_at"]))
        except (TypeError, KeyError, ValueError, OverflowError, OSError):
            r["remaining_pct"] = r["reset"] = None
        rows.append(r)
    return rows or [row("codex", bucket=bucket, source=source)]


def codex(now):
    home = os.environ.get("CODEX_HOME") or os.path.expanduser("~/.codex")
    files = glob.glob(os.path.join(home, "sessions", "*", "*", "*", "rollout-*.jsonl"))
    if not files:
        return stamp([row("codex")], UNKNOWN, None)
    newest = max(files, key=os.path.getmtime)
    age_s = int(max(now - os.path.getmtime(newest), 0))
    source = f"{os.path.basename(newest)} ({age(age_s)} old)"
    last = None
    acct = UNKNOWN
    with open(newest, encoding="utf-8", errors="replace") as f:
        for line in f:
            if '"rate_limits":{' in line:
                last = line
            elif acct == UNKNOWN and '"creator_account_id"' in line:
                try:
                    acct = account(json.loads(line)["payload"]["creator_account_id"])
                except (TypeError, KeyError, ValueError):
                    pass
    try:
        limits = json.loads(last)["payload"]["rate_limits"]
        if not isinstance(limits, dict):
            raise TypeError(limits)
    except (TypeError, KeyError, ValueError):
        return stamp([row("codex", source=source)], acct, age_s)
    return stamp(parse_codex_limits(limits, source), acct, age_s)


def claude(now):
    """Weekly limits from cachedUsageUtilization: {fetchedAtMs, utilization: {limits}}."""
    base = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~")
    try:
        with open(os.path.join(base, ".claude.json"), encoding="utf-8") as f:
            config = json.load(f)
    except (OSError, ValueError):
        return stamp([row("claude")], UNKNOWN, None)
    try:
        acct = account(config["oauthAccount"]["accountUuid"])
    except (TypeError, KeyError):
        acct = UNKNOWN
    try:
        cache = config["cachedUsageUtilization"]
    except (TypeError, KeyError):
        cache = None
    del config  # only the hash and the usage cache survive; email and names go here
    try:
        fetched = int(cache["fetchedAtMs"]) / 1000
        limits = cache["utilization"]["limits"]
        if not isinstance(limits, list):
            raise TypeError(limits)
    except (TypeError, KeyError, ValueError):
        return stamp([row("claude")], acct, None)
    age_s = int(max(now - fetched, 0))
    source = f"~/.claude.json cachedUsageUtilization ({age(age_s)} old)"
    rows = []
    for lim in limits:
        if not isinstance(lim, dict) or lim.get("group") != "weekly":
            continue
        r = row("claude", window="Weekly", source=source)
        try:
            model = ((lim.get("scope") or {}).get("model") or {}).get("display_name")
            r["bucket"] = model or "All models"
            used = float(lim["percent"])
            if not 0 <= used <= 100:
                raise ValueError(used)
            reset = datetime.fromisoformat(lim["resets_at"])
            if reset.tzinfo is None:
                raise ValueError(reset)
            r["remaining_pct"] = 100 - used
            r["reset"] = utc(reset.timestamp())
        except (AttributeError, TypeError, KeyError, ValueError):
            r["remaining_pct"] = r["reset"] = None
        rows.append(r)
    return stamp(rows or [row("claude", source=source)], acct, age_s)


def fmt(r):
    pct = UNKNOWN if r["remaining_pct"] is None else f"{r['remaining_pct']:g}%"
    return "\t".join(
        [r["agent"], r["bucket"], r["window"], pct, r["reset"] or UNKNOWN, r["source"]]
    )


def main():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--json", action="store_true", help="print a JSON list of rows")
    args = p.parse_args()
    now = time.time()
    rows = agy() + codex(now) + claude(now)
    if args.json:
        json.dump(rows, sys.stdout, indent=2)
        print()
    else:
        print("\n".join(fmt(r) for r in rows))


if __name__ == "__main__":
    main()
