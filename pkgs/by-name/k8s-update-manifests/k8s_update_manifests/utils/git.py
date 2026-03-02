"""Git utilities."""

import os
from pathlib import Path
from typing import Optional

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
