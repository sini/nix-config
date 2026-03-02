"""Data models for k8s-update-manifests."""

from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Optional


class SecretOperation(Enum):
    """Operations that can be performed on secrets."""

    CREATE = 1
    DELETE = 2
    UPDATE = 3
    NOOP = 4


@dataclass(frozen=True)
class SecretWorkItem:
    """Represents a secret file operation to be performed."""

    source_path: Optional[Path]
    target_path: Path
    op: SecretOperation


@dataclass(frozen=True)
class EnvironmentMetadata:
    """Metadata for a nixidy environment."""

    name: str
    repository: str
    branch: str
    output_path: Path
