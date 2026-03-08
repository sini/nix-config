"""Common utilities for command handlers."""

import argparse
import logging
import sys
from pathlib import Path

from ..utils import GitUtils


def configure_logging(verbose: bool = False) -> None:
    """Configure logging based on options.

    Args:
        verbose: If True, enable debug logging
    """
    logging.basicConfig(
        level=logging.DEBUG if verbose else logging.INFO,
        format="%(levelname)s: %(message)s",
    )


def validate_git_root(args: argparse.Namespace) -> Path:
    """Validate and return git repository root.

    Args:
        args: Parsed command line arguments

    Returns:
        Validated git root path

    Raises:
        SystemExit: If git root is invalid or not found
    """
    if hasattr(args, "git_root") and args.git_root:
        git_root = args.git_root.resolve()
        if not git_root.exists():
            logging.error(f"specified git root does not exist: {git_root}")
            sys.exit(1)
        return git_root

    git_root = GitUtils.get_root()
    if git_root is None:
        logging.error("not running from within a git repository")
        sys.exit(1)
    return git_root
