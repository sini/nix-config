"""Environment metadata data model."""

from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class EnvironmentMetadata:
    """Metadata for a nixidy environment."""

    name: str
    repository: str
    branch: str
    output_path: Path
