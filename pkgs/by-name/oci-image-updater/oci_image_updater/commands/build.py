"""Build command handlers."""

import argparse
import logging
from pathlib import Path

from ..images import ImageDiscovery
from ..utils import NixUtils
from .common import configure_logging


def cmd_build_image(args: argparse.Namespace) -> int:
    """Handle build-image command.

    Args:
        args: Parsed arguments

    Returns:
        Exit code
    """
    configure_logging()

    # Parse image path (e.g., "linuxserver/radarr")
    path_parts = args.image_path.split("/")

    logging.info(f"Building image: {args.image_path}")

    try:
        store_path = NixUtils.build_image(
            args.flake,
            path_parts,
            args.system,
        )
        logging.info(f"Built: {store_path}")
        print(store_path)
        return 0
    except Exception as e:
        logging.error(f"Failed to build image: {e}")
        return 1


def cmd_build_images(args: argparse.Namespace) -> int:
    """Handle build-images command.

    Args:
        args: Parsed arguments

    Returns:
        Exit code
    """
    configure_logging()

    logging.info("Fetching images metadata from flake...")
    metadata = NixUtils.get_images_metadata(args.flake)

    if not metadata:
        logging.warning("No images found in flake")
        return 0

    # We don't need git_root for this, just use a dummy path
    images = ImageDiscovery.discover_images(metadata, Path("/dev/null"))
    logging.info(f"Found {len(images)} image(s) to build")
    logging.info("")

    built_count = 0
    failed_count = 0

    for image in images:
        logging.info(f"Building {image.path_str}...")
        try:
            store_path = NixUtils.build_image(
                args.flake,
                image.path,
                args.system,
            )
            logging.info(f"  Built: {store_path}")
            built_count += 1
        except Exception as e:
            logging.error(f"  Failed to build: {e}")
            failed_count += 1
        logging.info("")

    logging.info(f"Summary: {built_count} built, {failed_count} failed")

    return 0 if failed_count == 0 else 1
