"""Main entry point for oci-image-updater."""

import argparse
import logging
import sys
from pathlib import Path

from .commands import (
    cmd_build_image,
    cmd_build_images,
    cmd_check_all,
    cmd_init,
    cmd_list_path,
    cmd_list_paths,
    cmd_update_all,
)


def parse_arguments() -> argparse.Namespace:
    """Parse command line arguments.

    Returns:
        Parsed arguments namespace
    """
    parser = argparse.ArgumentParser(
        description="Update OCI container image metadata"
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    # init command
    init_parser = subparsers.add_parser(
        "init",
        help="Initialize a new image metadata file",
    )
    init_parser.add_argument(
        "--image-name",
        required=True,
        help="Image name (e.g., linuxserver/radarr)",
    )
    init_parser.add_argument(
        "--image-tag",
        required=True,
        help="Image tag to track (e.g., nightly, latest, v1.2.3)",
    )
    init_parser.add_argument(
        "--arch",
        required=True,
        help="CPU architecture (e.g., amd64, arm64)",
    )
    init_parser.add_argument(
        "--os",
        required=True,
        help="Operating system (e.g., linux, darwin)",
    )
    init_parser.add_argument(
        "--git-root",
        type=Path,
        help="Git repository root path (auto-detected if not specified)",
    )
    init_parser.add_argument(
        "--pinned",
        action="store_true",
        help="Mark image as pinned (prevent automatic updates)",
    )

    # update-all command
    update_parser = subparsers.add_parser(
        "update-all",
        help="Update all image metadata files",
    )
    update_parser.add_argument(
        "--git-root",
        type=Path,
        help="Git repository root path (auto-detected if not specified)",
    )
    update_parser.add_argument(
        "--flake",
        type=str,
        default=".",
        help="Flake reference to use (default: current directory)",
    )
    update_parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be changed without actually making changes",
    )
    update_parser.add_argument(
        "--commit",
        action="store_true",
        help="Commit changes to git",
    )
    update_parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable debug logging",
    )

    # check-all command
    check_parser = subparsers.add_parser(
        "check-all",
        help="Check all images for updates without applying",
    )
    check_parser.add_argument(
        "--git-root",
        type=Path,
        help="Git repository root path (auto-detected if not specified)",
    )
    check_parser.add_argument(
        "--flake",
        type=str,
        default=".",
        help="Flake reference to use (default: current directory)",
    )

    # list-path command
    list_path_parser = subparsers.add_parser(
        "list-path",
        help="Get the store path for a specific image",
    )
    list_path_parser.add_argument(
        "image_path",
        help="Image path (e.g., linuxserver/radarr)",
    )
    list_path_parser.add_argument(
        "--flake",
        type=str,
        default=".",
        help="Flake reference to use (default: current directory)",
    )
    list_path_parser.add_argument(
        "--system",
        type=str,
        help="System platform (auto-detected if not specified)",
    )

    # list-paths command
    list_paths_parser = subparsers.add_parser(
        "list-paths",
        help="Get store paths for all images",
    )
    list_paths_parser.add_argument(
        "--flake",
        type=str,
        default=".",
        help="Flake reference to use (default: current directory)",
    )
    list_paths_parser.add_argument(
        "--system",
        type=str,
        help="System platform (auto-detected if not specified)",
    )

    # build-image command
    build_image_parser = subparsers.add_parser(
        "build-image",
        help="Build a specific image to populate the store",
    )
    build_image_parser.add_argument(
        "image_path",
        help="Image path (e.g., linuxserver/radarr)",
    )
    build_image_parser.add_argument(
        "--flake",
        type=str,
        default=".",
        help="Flake reference to use (default: current directory)",
    )
    build_image_parser.add_argument(
        "--system",
        type=str,
        help="System platform (auto-detected if not specified)",
    )

    # build-images command
    build_images_parser = subparsers.add_parser(
        "build-images",
        help="Build all images to populate the store",
    )
    build_images_parser.add_argument(
        "--flake",
        type=str,
        default=".",
        help="Flake reference to use (default: current directory)",
    )
    build_images_parser.add_argument(
        "--system",
        type=str,
        help="System platform (auto-detected if not specified)",
    )

    return parser.parse_args()


def main() -> int:
    """Main entry point.

    Returns:
        Exit code (0 for success, non-zero for failure)
    """
    args = parse_arguments()

    # Route to command handlers
    command_map = {
        "init": cmd_init,
        "update-all": cmd_update_all,
        "check-all": cmd_check_all,
        "list-path": cmd_list_path,
        "list-paths": cmd_list_paths,
        "build-image": cmd_build_image,
        "build-images": cmd_build_images,
    }

    handler = command_map.get(args.command)
    if handler:
        return handler(args)
    else:
        logging.error(f"Unknown command: {args.command}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
