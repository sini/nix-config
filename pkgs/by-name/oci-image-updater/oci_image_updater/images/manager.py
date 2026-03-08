"""Image update manager."""

import logging
from pathlib import Path
from typing import List

from ..models import UpdateOperation
from ..utils import GitUtils, NixUtils
from .discovery import ImageDiscovery
from .updater import ImageUpdater


class ImageManager:
    """Manages image discovery and updates."""

    def __init__(
        self,
        flake_ref: str,
        git_root: Path,
        dry_run: bool = False,
        commit: bool = False,
    ):
        """Initialize the image manager.

        Args:
            flake_ref: Flake reference
            git_root: Git repository root
            dry_run: If True, don't write changes
            commit: If True, commit changes
        """
        self.flake_ref = flake_ref
        self.git_root = git_root
        self.images_dir = git_root / "images"
        self.dry_run = dry_run
        self.commit = commit

    def update_all(self) -> List[UpdateOperation]:
        """Update all images.

        Returns:
            List of update operations performed
        """
        logging.info("Fetching images metadata from flake...")
        metadata = NixUtils.get_images_metadata(self.flake_ref)

        if not metadata:
            logging.warning("No images found in flake")
            return []

        logging.info("Discovering images...")
        images = ImageDiscovery.discover_images(metadata, self.images_dir)
        logging.info(f"Found {len(images)} image(s)")
        logging.info("")

        operations = []
        for image in images:
            op = ImageUpdater.update_image(image, dry_run=self.dry_run)
            operations.append(op)
            logging.info("")

        # Summarize
        updated_count = sum(1 for op in operations if op.updated)
        logging.info(
            f"Summary: {updated_count} image(s) updated, {len(operations) - updated_count} unchanged"
        )

        # Commit if requested
        if self.commit and updated_count > 0 and not self.dry_run:
            self._commit_changes(operations)

        return operations

    def _commit_changes(self, operations: List[UpdateOperation]) -> None:
        """Commit updated image metadata files.

        Args:
            operations: List of update operations
        """
        updated_ops = [op for op in operations if op.updated]
        if not updated_ops:
            return

        logging.info("")
        logging.info("Committing changes...")

        # Add all image files
        GitUtils.add([self.images_dir], self.git_root)

        # Create commit message
        if len(updated_ops) == 1:
            op = updated_ops[0]
            message = f"images: update {op.path}\n\n{op.old_digest[:12]} -> {op.new_digest[:12]}"
        else:
            message = f"images: update {len(updated_ops)} images\n\n"
            for op in updated_ops:
                message += (
                    f"- {op.path}: {op.old_digest[:12]} -> {op.new_digest[:12]}\n"
                )

        GitUtils.commit(message, self.git_root)
        logging.info("Changes committed")
