"""Filesystem scanning utilities."""

from pathlib import Path
from typing import List, Tuple


class FileSystemScanner:
    """Scans filesystem directories to find files and subdirectories."""

    @staticmethod
    def scan_path(path: Path) -> Tuple[List[Path], List[Path]]:
        """Scan a directory tree and return all files and directories.

        Args:
            path: Directory path to scan

        Returns:
            Tuple of (files, directories) as lists of Path objects
        """
        files: List[Path] = []
        directories: List[Path] = []
        for root, dirs, filenames in path.walk(follow_symlinks=True):
            directories.append(root)
            directories.extend(root / d for d in dirs)
            files.extend(root / f for f in filenames)
        return files, directories
