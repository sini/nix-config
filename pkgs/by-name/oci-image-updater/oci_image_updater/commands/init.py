"""Init command handler."""

import argparse
import logging

from ..images import ImageUpdater
from ..utils import NixUtils
from .common import configure_logging, validate_git_root


def cmd_init(args: argparse.Namespace) -> int:
    """Handle init command.

    Args:
        args: Parsed arguments

    Returns:
        Exit code
    """
    configure_logging()

    git_root = validate_git_root(args)
    images_dir = git_root / "images"

    logging.info(f"Initializing new image: {args.image_name}:{args.image_tag}")
    logging.info(f"Platform: {args.os}/{args.arch}")
    if args.pinned:
        logging.info("Pinned: true (automatic updates disabled)")
    logging.info("")

    # Fetch image metadata
    logging.info("Fetching image metadata...")
    try:
        prefetch_result = NixUtils.prefetch_docker(
            args.image_name,
            args.image_tag,
            args.arch,
            args.os,
        )
    except Exception as e:
        logging.error(f"Failed to fetch image: {e}")
        return 1

    image_digest = prefetch_result.get("imageDigest", "")
    image_hash = prefetch_result.get("hash", "")

    logging.info(f"  Digest: {image_digest}")
    logging.info(f"  Hash: {image_hash}")
    logging.info("")

    # Create file path based on image name
    # linuxserver/radarr -> images/linuxserver/radarr/default.nix
    path_parts = args.image_name.split("/")
    file_path = images_dir / "/".join(path_parts) / "default.nix"

    if file_path.exists():
        logging.error(f"Image metadata file already exists: {file_path}")
        return 1

    # Write metadata file
    ImageUpdater._write_metadata_file(
        file_path,
        args.image_name,
        args.image_tag,
        image_digest,
        image_hash,
        args.arch,
        args.os,
        args.pinned,
    )

    logging.info(f"Created {file_path}")
    logging.info("")
    logging.info("Don't forget to add this file to git:")
    logging.info(f"  git add {file_path}")

    return 0
