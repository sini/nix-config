"""Process execution utilities."""

import os
import subprocess
from pathlib import Path
from typing import Dict, List, Optional


class ProcessUtils:
    """Utility class for subprocess execution."""

    @staticmethod
    def run(
        cmd: List[str],
        *,
        cwd: Optional[Path] = None,
        input_text: Optional[str] = None,
        env: Optional[Dict[str, str]] = None,
    ) -> str:
        """Run a command, return stdout, raise on failure.

        Args:
            cmd: Command and arguments to execute
            cwd: Working directory for command execution
            input_text: Text to pass to stdin
            env: Additional environment variables to set

        Returns:
            Command stdout as string

        Raises:
            RuntimeError: If command exits with non-zero status
        """
        process_env = None
        if env is not None:
            process_env = os.environ.copy()
            process_env.update(env)

        process = subprocess.run(
            cmd,
            cwd=str(cwd) if cwd else None,
            input=input_text,
            text=True,
            capture_output=True,
            check=False,
            env=process_env,
        )
        if process.returncode != 0:
            raise RuntimeError(
                f"Command failed ({process.returncode}): {' '.join(cmd)}\n"
                f"--- stdout ---\n{process.stdout}\n"
                f"--- stderr ---\n{process.stderr}\n"
            )
        return process.stdout
