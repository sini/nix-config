#!/usr/bin/env python3
"""Update Kubernetes manifests for nixidy environments."""

import argparse
import os
import sys
from pathlib import Path


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Update Kubernetes manifests for nixidy environments"
    )

    args = parser.parse_args()

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
