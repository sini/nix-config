"""Image update manager."""

import logging
from dataclasses import replace
from pathlib import Path

from ..models import UpdateOperation
from ..utils import GitUtils, NixUtils
from .discovery import ImageDiscovery
from .updater import ImageUpdater

logger = logging.getLogger(__name__)


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

    def update_all(self) -> list[UpdateOperation]:
        """Update all images.

        Returns:
            List of update operations performed
        """
        logger.info("Fetching images metadata from flake...")
        metadata = NixUtils.get_images_metadata(self.flake_ref)

        if not metadata:
            logger.warning("No images found in flake")
            return []

        logger.info("Discovering images...")
        images = ImageDiscovery.discover_images(metadata, self.images_dir)
        logger.info(f"Found {len(images)} image(s)")
        logger.info("")

        operations = []
        for image in images:
            op = ImageUpdater.update_image(image, dry_run=self.dry_run)
            operations.append(op)
            logger.info("")

        # Summarize
        updated_count = sum(1 for op in operations if op.updated)
        logger.info(
            f"Summary: {updated_count} image(s) updated, {len(operations) - updated_count} unchanged"
        )

        # Commit if requested
        if self.commit and updated_count > 0 and not self.dry_run:
            self._commit_changes(operations, [self.images_dir])

        return operations

    def update_one(self, image_path: str, tag: str | None = None) -> UpdateOperation:
        """Update one image, optionally moving it to another tag.

        A named image is updated even when pinned: naming it is the operator's
        intent, and the pin still holds against update-all.

        Args:
            image_path: Image path under images/ (e.g., "sini/xmsg")
            tag: New tag to track; the file's tag when None

        Returns:
            The update operation

        Raises:
            KeyError: No image has that path
        """
        metadata = NixUtils.get_images_metadata(self.flake_ref)
        images = ImageDiscovery.discover_images(metadata or {}, self.images_dir)
        image = next((i for i in images if i.path_str == image_path), None)
        if image is None:
            known = ", ".join(sorted(i.path_str for i in images))
            raise KeyError(f"no image {image_path!r}; known: {known}")

        tag_changed = tag is not None and tag != image.image_tag
        if tag_changed:
            logger.info(f"Tag: {image.image_tag} -> {tag}")
            image = replace(image, image_tag=tag)

        op = ImageUpdater.update_image(
            image, dry_run=self.dry_run, explicit=True, tag_changed=tag_changed
        )
        if self.commit and op.updated and not self.dry_run:
            self._commit_changes([op], [image.file_path])
        return op

    def _commit_changes(
        self, operations: list[UpdateOperation], paths: list[Path]
    ) -> None:
        """Commit updated image metadata files.

        Args:
            operations: List of update operations
            paths: Files or directories to stage
        """
        updated_ops = [op for op in operations if op.updated]
        if not updated_ops:
            return

        logger.info("")
        logger.info("Committing changes...")

        GitUtils.add(paths, self.git_root)

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
        logger.info("Changes committed")
