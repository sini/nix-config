"""Data models for oci-image-updater."""

from .image_metadata import ImageMetadata
from .update_operation import UpdateOperation

__all__ = [
    "ImageMetadata",
    "UpdateOperation",
]
