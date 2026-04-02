"""Update command handlers."""

import argparse
import logging

from ..images import ImageDiscovery, ImageManager, ImageUpdater
from ..utils import NixUtils
from .common import configure_logging, validate_git_root


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
        logging.info("DRY RUN MODE: No changes will be made")
        logging.info("")

    logging.info(f"Git repository root: {git_root}")
    logging.info(f"Flake reference: {args.flake}")
    logging.info("")

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

    logging.info(f"Git repository root: {git_root}")
    logging.info(f"Flake reference: {args.flake}")
    logging.info("")

    logging.info("Fetching images metadata from flake...")
    metadata = NixUtils.get_images_metadata(args.flake)

    if not metadata:
        logging.warning("No images found in flake")
        return 0

    images_dir = git_root / "images"
    images = ImageDiscovery.discover_images(metadata, images_dir)
    logging.info(f"Found {len(images)} image(s)")
    logging.info("")

    updates_available = []
    for image in images:
        logging.info(f"Checking {image.path_str}...")
        if image.pinned:
            logging.info("  Pinned (skipping)")
        elif ImageUpdater.needs_update(image):
            remote_digest = ImageUpdater.check_remote_digest(
                image.image_name,
                image.image_tag,
                image.arch,
                image.os,
            )
            logging.info("  Update available!")
            logging.info(f"    Current: {image.image_digest}")
            logging.info(f"    Remote:  {remote_digest}")
            updates_available.append(image.path_str)
        else:
            logging.info("  Up to date")
        logging.info("")

    if updates_available:
        logging.info(f"{len(updates_available)} image(s) have updates available:")
        for path in updates_available:
            logging.info(f"  - {path}")
    else:
        logging.info("All images are up to date")

    return 0
