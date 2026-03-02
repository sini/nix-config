"""Environment synchronization between source and target directories."""

import logging
from pathlib import Path
from typing import List, Optional, Tuple

from .file_sync import FileSync
from .models import EnvironmentMetadata
from .secret_manager import SecretManager


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


class PathConverter:
    """Utility for converting between absolute and relative paths."""

    def __init__(self, base_path: Path):
        """Initialize PathConverter.

        Args:
            base_path: Base path for relative conversions
        """
        self.base_path = base_path

    def to_relative(self, file_path: Path) -> Path:
        """Convert absolute path to relative path from base.

        Args:
            file_path: Absolute path to convert

        Returns:
            Relative path from base
        """
        return file_path.relative_to(self.base_path)


class EnvironmentManager:
    """Manages environment synchronization between source and target directories."""

    def __init__(
        self,
        source: Path,
        environment: EnvironmentMetadata,
        git_root: Path,
        dry_run: bool = False,
        skip_secrets: bool = False,
    ):
        """Initialize EnvironmentManager.

        Args:
            source: Source directory path
            environment: Environment metadata
            git_root: Git repository root path
            dry_run: If True, don't write changes to disk
            skip_secrets: If True, don't process secrets
        """
        self.source = source
        self.environment = environment
        self.git_root = git_root
        self.dry_run = dry_run
        self.skip_secrets = skip_secrets

        # Scan source and target directories
        scanner = FileSystemScanner()
        self.source_files, self.source_dirs = scanner.scan_path(self.source)
        self.target_files, self.target_dirs = scanner.scan_path(
            self.environment.output_path
        )

        # Initialize path converters
        self.source_converter = PathConverter(self.source)
        self.target_converter = PathConverter(self.environment.output_path)

        # Initialize file sync
        self.file_sync = FileSync(
            source_path=self.source,
            target_path=self.environment.output_path,
            dry_run=self.dry_run,
        )

        # Initialize secret manager
        self.secret_manager: Optional[SecretManager] = None
        if not skip_secrets:
            self.secret_manager = SecretManager(
                source_path=self.source,
                target_path=self.environment.output_path,
                source_files=self.source_files,
                target_files=self.target_files,
                git_root=self.git_root,
                dry_run=self.dry_run,
            )

    def _is_secret_file(
        self,
        relative_path: Path,
        target_only: bool = False,
    ) -> bool:
        """Check if a file is managed as a secret.

        Args:
            relative_path: Relative path to check
            target_only: If True, only check target paths

        Returns:
            True if file is managed as a secret
        """
        if self.secret_manager is None:
            # Even when secret processing is disabled, we need to filter out
            # Secret-* and SopsSecret-* files from regular file sync
            filename = relative_path.name
            return filename.startswith("Secret-") or filename.startswith("SopsSecret-")
        return self.secret_manager.is_secret_file(relative_path, target_only)

    def update(self) -> None:
        """Synchronize target directory with source by computing and applying differences.

        Compares source and target directories to identify:
        - New files/directories to create
        - Existing files that need updates
        - Deleted files/directories to remove

        Then applies changes in the correct order to maintain consistency.
        """
        logging.info(f"Updating environment: {self.environment.name}")
        logging.info(f"Output path: {self.environment.output_path}")

        # Convert absolute paths to relative paths for comparison
        src_files = {
            rel_path
            for rel_path in (
                self.source_converter.to_relative(f) for f in self.source_files
            )
            if not self._is_secret_file(rel_path)
        }
        target_files = {
            rel_path
            for rel_path in (
                self.target_converter.to_relative(f) for f in self.target_files
            )
            if not self._is_secret_file(rel_path, target_only=True)
        }
        src_dirs = {self.source_converter.to_relative(d) for d in self.source_dirs}
        target_dirs = {self.target_converter.to_relative(d) for d in self.target_dirs}

        # Identify new files and directories (in source but not in target)
        new_files = src_files - target_files
        new_dirs = src_dirs - target_dirs

        # Identify existing files and check which ones need updates
        existing_files = src_files & target_files
        updated_files = {
            f for f in existing_files if self.file_sync.compare_files(f, f)
        }
        unchanged_files = existing_files - updated_files

        # Identify deleted files and directories (in target but not in source)
        deleted_files = target_files - src_files
        deleted_dirs = target_dirs - src_dirs

        # Apply changes in order: delete -> create dirs -> copy new -> update existing
        self.file_sync.delete_files(deleted_files)
        self.file_sync.delete_directories(deleted_dirs)
        self.file_sync.create_directories(new_dirs)
        self.file_sync.copy_files(new_files)
        self.file_sync.update_files(updated_files)

        # Process secrets if secret manager is initialized
        if self.secret_manager is not None:
            self.secret_manager.process_all()

        # Log summary statistics
        self._log_summary(
            new_dirs=new_dirs,
            new_files=new_files,
            updated_files=updated_files,
            deleted_files=deleted_files,
            deleted_dirs=deleted_dirs,
            unchanged_files=unchanged_files,
        )

    @staticmethod
    def _log_summary(
        *,
        new_dirs: set[Path],
        new_files: set[Path],
        updated_files: set[Path],
        deleted_files: set[Path],
        deleted_dirs: set[Path],
        unchanged_files: set[Path],
    ) -> None:
        """Log summary statistics for the update operation.

        Args:
            new_dirs: Set of newly created directories
            new_files: Set of newly created files
            updated_files: Set of updated files
            deleted_files: Set of deleted files
            deleted_dirs: Set of deleted directories
            unchanged_files: Set of unchanged files
        """
        if new_dirs:
            logging.info(f"{len(new_dirs)} director(ies) created")
        if new_files:
            logging.info(f"{len(new_files)} file(s) created")
        if updated_files:
            logging.info(f"{len(updated_files)} file(s) updated")
        if deleted_files:
            logging.info(f"{len(deleted_files)} file(s) deleted")
        if deleted_dirs:
            logging.info(f"{len(deleted_dirs)} director(ies) deleted")
        if unchanged_files:
            logging.info(f"{len(unchanged_files)} file(s) unchanged")
