"""Git utilities."""

import os
from pathlib import Path
from typing import List, Optional

from .process import ProcessUtils


class GitUtils:
    """Utility class for git operations."""

    @staticmethod
    def get_root() -> Optional[Path]:
        """Get the root directory of the current git repository.

        Returns:
            Path to the git repository root, or None if not in a git repo.
        """
        try:
            output = ProcessUtils.run(
                ["git", "rev-parse", "--show-toplevel"],
                cwd=Path(os.getcwd()),
            )
            return Path(output.strip())
        except Exception:
            return None

    @staticmethod
    def add(paths: List[Path], git_root: Path) -> None:
        """Add files to git staging area.

        Args:
            paths: List of file paths to add
            git_root: Git repository root directory
        """
        if not paths:
            return
        ProcessUtils.run(
            ["git", "add"] + [str(p) for p in paths],
            cwd=git_root,
        )

    @staticmethod
    def commit(message: str, git_root: Path) -> None:
        """Create a git commit.

        Args:
            message: Commit message
            git_root: Git repository root directory
        """
        ProcessUtils.run(
            ["git", "commit", "-m", message],
            cwd=git_root,
        )
