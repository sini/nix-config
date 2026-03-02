"""File and directory synchronization operations."""

import difflib
import filecmp
import logging
import os
import shutil
from pathlib import Path


class FileSync:
    """Handles file and directory synchronization operations."""

    def __init__(
        self,
        source_path: Path,
        target_path: Path,
        dry_run: bool = False,
    ):
        """Initialize FileSync.

        Args:
            source_path: Source directory path
            target_path: Target directory path
            dry_run: If True, don't write changes to disk
        """
        self.source_path = source_path
        self.target_path = target_path
        self.dry_run = dry_run

    @staticmethod
    def _compute_diff(original_path: Path, modified_path: Path) -> str:
        """Generate a unified diff between two files.

        Args:
            original_path: Path to the original file
            modified_path: Path to the modified file

        Returns:
            Unified diff as a string
        """
        with open(original_path, "r") as f:
            original_lines = f.readlines()
        with open(modified_path, "r") as f:
            modified_lines = f.readlines()

        diff = difflib.unified_diff(
            original_lines,
            modified_lines,
            fromfile=str(original_path),
            tofile=str(modified_path),
            lineterm="\n",
        )
        return "".join(diff)

    def compare_files(self, source_file: Path, target_file: Path) -> bool:
        """Compare two files for differences.

        Args:
            source_file: Source file path (relative)
            target_file: Target file path (relative)

        Returns:
            True if files differ, False if identical
        """
        return not filecmp.cmp(
            self.source_path / source_file,
            self.target_path / target_file,
            shallow=False,
        )

    def copy_files(self, files: set[Path]) -> None:
        """Copy files from source to target directory.

        Args:
            files: Set of relative file paths to copy
        """
        for file_path in files:
            source_file = self.source_path / file_path
            target_file = self.target_path / file_path

            if self.dry_run:
                logging.debug(f"[DRY RUN] Would create file: ./{file_path}")
            else:
                shutil.copy2(source_file, target_file)
                # Make writable (source may be read-only from nix)
                os.chmod(target_file, 0o644)
                logging.debug(f"Created file: ./{file_path}")

    def update_files(self, files: set[Path]) -> None:
        """Update files from source to target directory.

        Args:
            files: Set of relative file paths to update
        """
        for file_path in files:
            source_file = self.source_path / file_path
            target_file = self.target_path / file_path
            diff = self._compute_diff(target_file, source_file)

            if self.dry_run:
                logging.debug(f"[DRY RUN] Would update file: ./{file_path}")
            else:
                shutil.copy2(source_file, target_file)
                # Make writable (source may be read-only from nix)
                os.chmod(target_file, 0o644)
                logging.debug(f"Updated file: ./{file_path}")

            if diff:
                logging.debug(f"DIFF:\n{diff}")

    def delete_files(self, files: set[Path]) -> None:
        """Delete files from target directory.

        Args:
            files: Set of relative file paths to delete
        """
        for file_path in files:
            target_file = self.target_path / file_path
            if target_file.exists() and target_file.is_file():
                if self.dry_run:
                    logging.debug(f"[DRY RUN] Would delete: {file_path}")
                else:
                    target_file.unlink()
                    logging.debug(f"Delete: {file_path}")

    def create_directories(self, dirs: set[Path]) -> None:
        """Create directories in sorted order (parents before children).

        Args:
            dirs: Set of relative directory paths to create
        """
        sorted_dirs = sorted(dirs, key=lambda d: (len(d.parts), str(d)))
        for dir_path in sorted_dirs:
            target_dir = self.target_path / dir_path
            if self.dry_run:
                logging.debug(f"[DRY RUN] Would create directory: ./{dir_path}")
            else:
                target_dir.mkdir(parents=True, exist_ok=True)
                logging.debug(f"Created directory: ./{dir_path}")

    def delete_directories(self, dirs: set[Path]) -> None:
        """Remove directories in reverse sorted order (children before parents).

        Args:
            dirs: Set of relative directory paths to delete
        """
        sorted_dirs = sorted(dirs, key=lambda d: (len(d.parts), str(d)), reverse=True)
        for dir_path in sorted_dirs:
            target_dir = self.target_path / dir_path
            if target_dir.exists() and target_dir.is_dir():
                if self.dry_run:
                    logging.debug(f"[DRY RUN] Would remove: ./{dir_path}")
                else:
                    target_dir.rmdir()
                    logging.debug(f"Removed: ./{dir_path}")
