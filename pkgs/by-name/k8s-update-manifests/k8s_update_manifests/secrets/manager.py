"""Secret management orchestration."""

import logging
from pathlib import Path
from typing import List

from ..models import SecretOperation
from .discovery import SecretDiscovery
from .processor import SecretProcessor


class SecretManager:
    """Manages secret discovery, conversion, and encryption for environments."""

    def __init__(
        self,
        source_path: Path,
        target_path: Path,
        source_files: List[Path],
        target_files: List[Path],
        git_root: Path,
        dry_run: bool = False,
    ):
        """Initialize SecretManager.

        Args:
            source_path: Source directory path
            target_path: Target directory path
            source_files: List of all source files
            target_files: List of all target files
            git_root: Git repository root path
            dry_run: If True, don't write changes to disk
        """
        self.source_path = source_path
        self.target_path = target_path
        self.git_root = git_root
        self.dry_run = dry_run

        # Initialize discovery and processor
        self.discovery = SecretDiscovery(
            source_path, target_path, source_files, target_files
        )
        self.processor = SecretProcessor(source_path, target_path, git_root, dry_run)

        # Discover secrets
        self.work_items = self.discovery.discover()

    def process_all(self) -> None:
        """Process all discovered secrets."""
        for work_item in self.work_items:
            logging.debug(f"Processing secret: {work_item}")
            match work_item.op:
                case SecretOperation.CREATE:
                    self.processor.process_create(work_item)
                case SecretOperation.UPDATE:
                    self.processor.process_update(work_item)
                case SecretOperation.DELETE:
                    self.processor.process_delete(work_item)
                case SecretOperation.NOOP:
                    # TODO: Optionally verify encryption keys...
                    pass

    def is_secret_file(
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
        for work_item in self.work_items:
            if work_item.op == SecretOperation.NOOP:
                continue
            if work_item.target_path == relative_path:
                return True
            if not target_only and work_item.source_path == relative_path:
                return True
        return False
