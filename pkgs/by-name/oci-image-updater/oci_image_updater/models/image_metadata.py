"""Image metadata model."""

from dataclasses import dataclass
from pathlib import Path


@dataclass
class ImageMetadata:
    """Metadata for an OCI container image.

    Attributes:
        path: Path components (e.g., ["linuxserver", "radarr"])
        image_name: Full image name (e.g., "linuxserver/radarr")
        image_tag: Tag to track (e.g., "nightly", "latest")
        image_digest: Current SHA256 digest (e.g., "sha256:...")
        image_hash: Current Nix SRI hash (e.g., "sha256-...")
        arch: CPU architecture (e.g., "amd64", "arm64")
        os: Operating system (e.g., "linux", "darwin")
        pinned: If True, prevent automatic updates
        file_path: Path to the metadata file
    """

    path: list[str]
    image_name: str
    image_tag: str
    image_digest: str
    image_hash: str
    arch: str
    os: str
    pinned: bool
    file_path: Path

    @property
    def path_str(self) -> str:
        """Get path as a string (e.g., "linuxserver/radarr").

        Returns:
            Path string joined with slashes
        """
        return "/".join(self.path)
