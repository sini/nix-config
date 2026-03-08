"""Update OCI container image metadata.

This package provides tools for tracking and updating OCI container images
in a Nix flake, with automatic digest and hash updates.
"""

__version__ = "1.0.0"

from .images import ImageDiscovery, ImageManager, ImageUpdater
from .models import ImageMetadata, UpdateOperation
from .utils import GitUtils, NixUtils, ProcessUtils

__all__ = [
    "GitUtils",
    "ImageDiscovery",
    "ImageManager",
    "ImageMetadata",
    "ImageUpdater",
    "NixUtils",
    "ProcessUtils",
    "UpdateOperation",
]
