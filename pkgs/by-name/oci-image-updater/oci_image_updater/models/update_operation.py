"""Update operation model."""

from dataclasses import dataclass


@dataclass
class UpdateOperation:
    """Represents an image update operation.

    Attributes:
        path: Image path (e.g., "linuxserver/radarr")
        old_digest: Previous image digest
        new_digest: New image digest
        old_hash: Previous Nix hash
        new_hash: New Nix hash
        updated: Whether the image was actually updated
    """

    path: str
    old_digest: str
    new_digest: str
    old_hash: str
    new_hash: str
    updated: bool
