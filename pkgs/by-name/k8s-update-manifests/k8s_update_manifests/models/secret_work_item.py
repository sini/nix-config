"""Secret work item data model."""

from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from .secret_operation import SecretOperation


@dataclass(frozen=True)
class SecretWorkItem:
    """Represents a secret file operation to be performed."""

    source_path: Optional[Path]
    target_path: Path
    op: SecretOperation
