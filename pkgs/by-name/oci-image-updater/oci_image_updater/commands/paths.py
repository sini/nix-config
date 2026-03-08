"""Path listing command handlers."""

import argparse
import json
import logging
from pathlib import Path

from ..images import ImageDiscovery
from ..utils import NixUtils
from .common import configure_logging


def cmd_list_path(args: argparse.Namespace) -> int:
    """Handle list-path command.

    Args:
        args: Parsed arguments

    Returns:
        Exit code
    """
    configure_logging()

    # Parse image path (e.g., "linuxserver/radarr")
    path_parts = args.image_path.split("/")

    try:
        store_path = NixUtils.get_image_store_path(
            args.flake,
            path_parts,
            args.system,
        )
        print(store_path)
        return 0
    except Exception as e:
        logging.error(f"Failed to get store path: {e}")
        return 1


def cmd_list_paths(args: argparse.Namespace) -> int:
    """Handle list-paths command.

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
        # Output empty JSON array
        print(json.dumps([]))
        return 0

    # We don't need git_root for this, just use a dummy path
    images = ImageDiscovery.discover_images(metadata, Path("/dev/null"))
    logging.info(f"Found {len(images)} image(s)")
    logging.info("")

    # Build list of path objects
    paths = []
    for image in images:
        try:
            store_path = NixUtils.get_image_store_path(
                args.flake,
                image.path,
                args.system,
            )
            paths.append(
                {
                    "image": image.path_str,
                    "path": str(store_path),
                }
            )
        except Exception as e:
            logging.error(f"Failed to get store path for {image.path_str}: {e}")

    # Output JSON
    print(json.dumps(paths, indent=2))

    return 0
