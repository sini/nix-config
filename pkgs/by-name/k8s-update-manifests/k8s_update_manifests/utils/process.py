"""Process execution utilities."""

import os
import subprocess
import sys
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
        stream_output: bool = False,
    ) -> str:
        """Run a command, return stdout, raise on failure.

        Args:
            cmd: Command and arguments to execute
            cwd: Working directory for command execution
            input_text: Text to pass to stdin
            env: Additional environment variables to set
            stream_output: If True, stream output to terminal in real-time

        Returns:
            Command stdout as string

        Raises:
            RuntimeError: If command exits with non-zero status
        """
        process_env = None
        if env is not None:
            process_env = os.environ.copy()
            process_env.update(env)

        if stream_output:
            # Stream output in real-time while also capturing it
            process = subprocess.Popen(
                cmd,
                cwd=str(cwd) if cwd else None,
                stdin=subprocess.PIPE if input_text else None,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,  # Merge stderr into stdout
                text=True,
                bufsize=1,  # Line buffered
                env=process_env,
            )

            stdout_lines = []
            if input_text:
                process.stdin.write(input_text)
                process.stdin.close()

            # Read and display output line by line
            for line in process.stdout:
                sys.stdout.write(line)
                sys.stdout.flush()
                stdout_lines.append(line)

            process.wait()
            stdout = "".join(stdout_lines)

            if process.returncode != 0:
                raise RuntimeError(
                    f"Command failed ({process.returncode}): {' '.join(cmd)}"
                )
            return stdout
        else:
            # Original behavior: capture all output
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
