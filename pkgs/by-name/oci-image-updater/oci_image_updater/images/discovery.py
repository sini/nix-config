"""Image discovery from flake metadata."""

import logging
from pathlib import Path
from typing import Any, Dict, List

from ..models import ImageMetadata


class ImageDiscovery:
    """Discovers images from flake metadata."""

    @staticmethod
    def discover_images(
        metadata: Dict[str, Any],
        images_dir: Path,
    ) -> List[ImageMetadata]:
        """Discover all images from flake metadata.

        Args:
            metadata: Nested dict of image metadata from flake
            images_dir: Root directory for image metadata files

        Returns:
            List of ImageMetadata objects
        """
        images = []
        ImageDiscovery._discover_recursive(
            metadata,
            images_dir,
            path_components=[],
            images=images,
        )
        return images

    @staticmethod
    def _discover_recursive(
        node: Any,
        base_path: Path,
        path_components: List[str],
        images: List[ImageMetadata],
    ) -> None:
        """Recursively discover images from nested metadata.

        Args:
            node: Current node in metadata tree
            base_path: Base path for building file paths
            path_components: Current path components
            images: List to append discovered images to
        """
        if not isinstance(node, dict):
            return

        # Check if this is an image leaf node
        if "imageName" in node and "imageTag" in node:
            # This is an image metadata node
            file_path = base_path / "/".join(path_components) / "default.nix"

            image = ImageMetadata(
                path=path_components.copy(),
                image_name=node["imageName"],
                image_tag=node["imageTag"],
                image_digest=node.get("imageDigest", ""),
                image_hash=node.get("imageHash", ""),
                arch=node.get("arch", "amd64"),
                os=node.get("os", "linux"),
                pinned=node.get("pinned", False),
                file_path=file_path,
            )
            images.append(image)
            logging.debug(f"Discovered image: {image.path_str}")
        else:
            # This is a directory node, recurse into children
            for key, value in node.items():
                ImageDiscovery._discover_recursive(
                    value,
                    base_path,
                    path_components + [key],
                    images,
                )
