"""Init command handler."""

import argparse
import logging

from ..images import ImageUpdater
from ..utils import NixUtils
from .common import configure_logging, validate_git_root

logger = logging.getLogger(__name__)


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

    logger.info(f"Initializing new image: {args.image_name}:{args.image_tag}")
    logger.info(f"Platform: {args.os}/{args.arch}")
    if args.pinned:
        logger.info("Pinned: true (automatic updates disabled)")
    logger.info("")

    # Fetch image metadata
    logger.info("Fetching image metadata...")
    try:
        prefetch_result = NixUtils.prefetch_docker(
            args.image_name,
            args.image_tag,
            args.arch,
            args.os,
        )
    # RuntimeError: nix-prefetch-docker failed; OSError: it is not on PATH.
    except (RuntimeError, OSError) as e:
        logger.error(f"Failed to fetch image: {e}")
        return 1

    image_digest = prefetch_result.get("imageDigest", "")
    image_hash = prefetch_result.get("hash", "")

    logger.info(f"  Digest: {image_digest}")
    logger.info(f"  Hash: {image_hash}")
    logger.info("")

    # Create file path based on image name
    # linuxserver/radarr -> images/linuxserver/radarr/default.nix
    # ghcr.io/org/name -> images/org/name/default.nix: the flake loads two
    # levels (<ns>/<name>), so a registry host is not a path component.
    path_parts = args.image_name.split("/")
    if len(path_parts) > 2 and ("." in path_parts[0] or ":" in path_parts[0]):
        path_parts = path_parts[1:]
    file_path = images_dir / "/".join(path_parts) / "default.nix"

    if file_path.exists():
        logger.error(f"Image metadata file already exists: {file_path}")
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

    logger.info(f"Created {file_path}")
    logger.info("")
    logger.info("Don't forget to add this file to git:")
    logger.info(f"  git add {file_path}")

    return 0
