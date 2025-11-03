#!/usr/bin/env python3
"""Filter ZFS diff output by excluding persisted and ignored paths."""

import argparse
import re
import subprocess
import sys
from typing import List, Set


def get_persist_files(prefix: str) -> Set[str]:
    """Get list of files under a prefix, removing the prefix from paths."""
    try:
        result = subprocess.run(
            ["sudo", "find", prefix, "-type", "f"],
            capture_output=True,
            text=True,
            check=True,
        )
        return {
            line.removeprefix(prefix).lstrip("/")
            for line in result.stdout.strip().split("\n")
            if line
        }
    except subprocess.CalledProcessError:
        return set()


def get_ignore_patterns(ignore_file: str) -> List[re.Pattern]:
    """Load ignore patterns from file."""
    try:
        with open(ignore_file, "r") as f:
            patterns = []
            for line in f:
                line = line.strip()
                if line:
                    # Convert to regex pattern, anchored at start
                    patterns.append(re.compile(f"^{re.escape(line)}"))
            return patterns
    except FileNotFoundError:
        return []


def should_filter(
    path: str,
    persist_files: Set[str],
    cache_files: Set[str],
    ignore_patterns: List[re.Pattern],
) -> bool:
    """Check if a path should be filtered out."""
    # Remove leading ./ if present
    path = path.lstrip("./")

    # Check if path is in persist or cache files (exact match)
    if path in persist_files or path in cache_files:
        return True

    # Check against ignore patterns
    for pattern in ignore_patterns:
        if pattern.match(path):
            return True

    return False


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Filter ZFS diff output by excluding persisted and ignored paths"
    )
    parser.add_argument("dataset", help="ZFS dataset to diff (e.g., zroot/local/root)")
    parser.add_argument("ignore_file", help="File containing ignore patterns")
    parser.add_argument(
        "--skim-bin", default="sk", help="Path to skim binary (default: sk)"
    )

    args = parser.parse_args()

    # Get ZFS diff output
    try:
        result = subprocess.run(
            ["sudo", "zfs", "diff", "-F", f"{args.dataset}@empty"],
            capture_output=True,
            text=True,
            check=True,
        )
    except subprocess.CalledProcessError as e:
        print(f"Error running zfs diff: {e}", file=sys.stderr)
        return 1

    # Collect persist and cache files
    persist_files = get_persist_files("/persist/")
    cache_files = get_persist_files("/cache/")

    # Load ignore patterns
    ignore_patterns = get_ignore_patterns(args.ignore_file)

    # Process ZFS diff output
    filtered_lines = []
    for line in result.stdout.split("\n"):
        if not line:
            continue

        # Parse ZFS diff output: flag timestamp path
        parts = line.split("\t")
        if len(parts) < 3:
            continue

        flag, timestamp, path = parts[0], parts[1], parts[2]

        # Skip @ and / entries
        if timestamp in ("@", "/"):
            continue

        # Filter the path
        if not should_filter(path, persist_files, cache_files, ignore_patterns):
            filtered_lines.append(path)

    # Output to skim
    if filtered_lines:
        try:
            subprocess.run(
                [args.skim_bin], input="\n".join(filtered_lines), text=True
            )
        except KeyboardInterrupt:
            pass

    return 0


if __name__ == "__main__":
    sys.exit(main())
