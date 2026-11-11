#!/usr/bin/env python3
"""Print the remaining weekly usage quota of the agy, codex and claude agents.

Read-only and credential-free: agy answers `agy -p /quota` locally without a model call
(its Gemini Models bucket only), codex's figures come from the rate_limits object its own
session rollouts record, and claude's from the cachedUsageUtilization field Claude Code
keeps in ~/.claude.json (the data /usage shows, stamped with its fetch time). Only weekly
windows are printed. No token or auth file is opened. A source that is missing or
unparseable prints unknown.
"""

import argparse
import glob
import json
import os
import subprocess
import sys
import tempfile
import time
from datetime import UTC, datetime

UNKNOWN = "unknown"
WEEK_MINUTES = 10080
AGY_BUCKET = "Gemini Models"


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


def agy():
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
            return [row("agy")]
    if out.returncode != 0:
        return [row("agy")]
    return parse_agy(out.stdout)


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
        return [row("codex")]
    newest = max(files, key=os.path.getmtime)
    source = f"{os.path.basename(newest)} ({age(now - os.path.getmtime(newest))} old)"
    last = None
    with open(newest, encoding="utf-8", errors="replace") as f:
        for line in f:
            if '"rate_limits":{' in line:
                last = line
    try:
        limits = json.loads(last)["payload"]["rate_limits"]
        if not isinstance(limits, dict):
            raise TypeError(limits)
    except (TypeError, KeyError, ValueError):
        return [row("codex", source=source)]
    return parse_codex_limits(limits, source)


def claude(now):
    """Weekly limits from cachedUsageUtilization: {fetchedAtMs, utilization: {limits}}."""
    base = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~")
    try:
        with open(os.path.join(base, ".claude.json"), encoding="utf-8") as f:
            cache = json.load(f)["cachedUsageUtilization"]
        fetched = int(cache["fetchedAtMs"]) / 1000
        limits = cache["utilization"]["limits"]
        if not isinstance(limits, list):
            raise TypeError(limits)
    except (OSError, TypeError, KeyError, ValueError):
        return [row("claude")]
    source = f"~/.claude.json cachedUsageUtilization ({age(now - fetched)} old)"
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
    return rows or [row("claude", source=source)]


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
