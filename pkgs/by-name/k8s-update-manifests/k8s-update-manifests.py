#!/usr/bin/env python3
"""Update Kubernetes manifests for nixidy environments."""

import argparse
import os
import subprocess
import sys
from pathlib import Path


def get_git_root() -> Path | None:
    """Get the root directory of the current git repository.

    Returns:
        Path to the git repository root, or None if not in a git repo.
    """
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            check=True,
            cwd=os.getcwd(),
        )
        return Path(result.stdout.strip())
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Update Kubernetes manifests for nixidy environments"
    )

    args = parser.parse_args()

    # Detect git repository root
    git_root = get_git_root()
    if git_root is None:
        print("Error: not running from within a git repository", file=sys.stderr)
        return 1

    print(f"Git repository root: {git_root}")
    print()

    # Find the environments directory relative to this script
    script_path = Path(__file__).resolve()
    envs_dir = script_path.parent.parent / "share" / "nixidy-environments"

    if not envs_dir.exists():
        print(f"Error: environments directory not found at {envs_dir}", file=sys.stderr)
        return 1

    # Discover environments from symlinks
    environments = {}
    for entry in sorted(envs_dir.iterdir()):
        if entry.is_symlink():
            environments[entry.name] = str(entry.resolve())

    if not environments:
        print("Error: no environments found", file=sys.stderr)
        return 1

    # Print environment mappings
    for env, path in environments.items():
        print(f"{env} -> {path}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
