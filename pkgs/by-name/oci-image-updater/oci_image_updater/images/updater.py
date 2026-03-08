"""Image updater logic."""

import logging
from pathlib import Path
from typing import Optional

from ..models import ImageMetadata, UpdateOperation
from ..utils import NixUtils, ProcessUtils


class ImageUpdater:
    """Updates image metadata files."""

    @staticmethod
    def check_remote_digest(
        image_name: str,
        image_tag: str,
        arch: str,
        os: str,
    ) -> Optional[str]:
        """Check remote image digest using skopeo.

        Args:
            image_name: Image name (e.g., "linuxserver/radarr")
            image_tag: Image tag (e.g., "nightly")
            arch: Architecture (e.g., "amd64")
            os: Operating system (e.g., "linux")

        Returns:
            Remote image digest, or None if check failed
        """
        try:
            cmd = [
                "skopeo",
                "inspect",
                "--format",
                "{{.Digest}}",
                f"docker://{image_name}:{image_tag}",
                "--override-arch",
                arch,
                "--override-os",
                os,
            ]
            output = ProcessUtils.run(cmd)
            return output.strip()
        except Exception as e:
            logging.warning(
                f"Failed to check remote digest for {image_name}:{image_tag}: {e}"
            )
            return None

    @staticmethod
    def needs_update(image: ImageMetadata) -> bool:
        """Check if an image needs updating.

        Args:
            image: Image metadata to check

        Returns:
            True if the remote digest differs from stored digest
        """
        remote_digest = ImageUpdater.check_remote_digest(
            image.image_name,
            image.image_tag,
            image.arch,
            image.os,
        )

        if remote_digest is None:
            return False

        return remote_digest != image.image_digest

    @staticmethod
    def update_image(image: ImageMetadata, dry_run: bool = False) -> UpdateOperation:
        """Update an image's metadata file.

        Args:
            image: Image metadata to update
            dry_run: If True, don't write changes

        Returns:
            UpdateOperation describing what was done
        """
        logging.info(f"Checking {image.path_str}...")

        # Check if image is pinned
        if image.pinned:
            logging.info(f"  Pinned (skipping)")
            return UpdateOperation(
                path=image.path_str,
                old_digest=image.image_digest,
                new_digest=image.image_digest,
                old_hash=image.image_hash,
                new_hash=image.image_hash,
                updated=False,
            )

        remote_digest = ImageUpdater.check_remote_digest(
            image.image_name,
            image.image_tag,
            image.arch,
            image.os,
        )

        if remote_digest is None:
            logging.warning(f"  Skipping (failed to get remote digest)")
            return UpdateOperation(
                path=image.path_str,
                old_digest=image.image_digest,
                new_digest=image.image_digest,
                old_hash=image.image_hash,
                new_hash=image.image_hash,
                updated=False,
            )

        if remote_digest == image.image_digest:
            logging.info(f"  Up to date")
            return UpdateOperation(
                path=image.path_str,
                old_digest=image.image_digest,
                new_digest=remote_digest,
                old_hash=image.image_hash,
                new_hash=image.image_hash,
                updated=False,
            )

        logging.info(f"  Update available!")
        logging.info(f"    Old digest: {image.image_digest}")
        logging.info(f"    New digest: {remote_digest}")

        # Fetch new image and get hash
        prefetch_result = NixUtils.prefetch_docker(
            image.image_name,
            image.image_tag,
            image.arch,
            image.os,
        )

        new_hash = prefetch_result.get("hash", "")
        logging.info(f"    Old hash: {image.image_hash}")
        logging.info(f"    New hash: {new_hash}")

        if not dry_run:
            ImageUpdater._write_metadata_file(
                image.file_path,
                image.image_name,
                image.image_tag,
                remote_digest,
                new_hash,
                image.arch,
                image.os,
                image.pinned,
            )
            logging.info(f"  Updated {image.file_path}")
        else:
            logging.info(f"  Would update {image.file_path}")

        return UpdateOperation(
            path=image.path_str,
            old_digest=image.image_digest,
            new_digest=remote_digest,
            old_hash=image.image_hash,
            new_hash=new_hash,
            updated=True,
        )

    @staticmethod
    def _write_metadata_file(
        file_path: Path,
        image_name: str,
        image_tag: str,
        image_digest: str,
        image_hash: str,
        arch: str,
        os: str,
        pinned: bool = False,
    ) -> None:
        """Write image metadata to a Nix file.

        Args:
            file_path: Path to write the file
            image_name: Image name
            image_tag: Image tag
            image_digest: Image digest
            image_hash: Nix hash
            arch: Architecture
            os: Operating system
            pinned: If True, prevent automatic updates
        """
        pinned_str = "true" if pinned else "false"
        content = f"""{{
  imageName = "{image_name}";
  imageTag = "{image_tag}";
  imageDigest = "{image_digest}";
  imageHash = "{image_hash}";
  arch = "{arch}";
  os = "{os}";
  pinned = {pinned_str};
}}
"""
        file_path.parent.mkdir(parents=True, exist_ok=True)
        file_path.write_text(content)
