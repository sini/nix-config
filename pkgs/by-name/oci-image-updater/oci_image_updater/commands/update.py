"""Update command handlers."""

import argparse
import logging

from ..images import ImageDiscovery, ImageManager, ImageUpdater
from ..utils import NixUtils
from .common import configure_logging, validate_git_root

logger = logging.getLogger(__name__)


def cmd_update_all(args: argparse.Namespace) -> int:
    """Handle update-all command.

    Args:
        args: Parsed arguments

    Returns:
        Exit code
    """
    configure_logging(args.verbose)

    git_root = validate_git_root(args)

    if args.dry_run:
        logger.info("DRY RUN MODE: No changes will be made")
        logger.info("")

    logger.info(f"Git repository root: {git_root}")
    logger.info(f"Flake reference: {args.flake}")
    logger.info("")

    manager = ImageManager(
        flake_ref=args.flake,
        git_root=git_root,
        dry_run=args.dry_run,
        commit=args.commit,
    )

    manager.update_all()

    return 0


def cmd_check_all(args: argparse.Namespace) -> int:
    """Handle check-all command.

    Args:
        args: Parsed arguments

    Returns:
        Exit code
    """
    configure_logging()

    git_root = validate_git_root(args)

    logger.info(f"Git repository root: {git_root}")
    logger.info(f"Flake reference: {args.flake}")
    logger.info("")

    logger.info("Fetching images metadata from flake...")
    metadata = NixUtils.get_images_metadata(args.flake)

    if not metadata:
        logger.warning("No images found in flake")
        return 0

    images_dir = git_root / "images"
    images = ImageDiscovery.discover_images(metadata, images_dir)
    logger.info(f"Found {len(images)} image(s)")
    logger.info("")

    updates_available = []
    for image in images:
        logger.info(f"Checking {image.path_str}...")
        if image.pinned:
            logger.info("  Pinned (skipping)")
        elif ImageUpdater.needs_update(image):
            remote_digest = ImageUpdater.check_remote_digest(
                image.image_name,
                image.image_tag,
                image.arch,
                image.os,
            )
            logger.info("  Update available!")
            logger.info(f"    Current: {image.image_digest}")
            logger.info(f"    Remote:  {remote_digest}")
            updates_available.append(image.path_str)
        else:
            logger.info("  Up to date")
        logger.info("")

    if updates_available:
        logger.info(f"{len(updates_available)} image(s) have updates available:")
        for path in updates_available:
            logger.info(f"  - {path}")
    else:
        logger.info("All images are up to date")

    return 0
