"""Secret discovery logic."""

from pathlib import Path
from typing import List

from ..models import SecretOperation, SecretWorkItem


class SecretDiscovery:
    """Discovers secrets and determines required operations."""

    def __init__(
        self,
        source_path: Path,
        target_path: Path,
        source_files: List[Path],
        target_files: List[Path],
    ):
        """Initialize SecretDiscovery.

        Args:
            source_path: Source directory path
            target_path: Target directory path
            source_files: List of all source files (absolute paths)
            target_files: List of all target files (absolute paths)
        """
        self.source_path = source_path
        self.target_path = target_path
        self.source_files = source_files
        self.target_files = target_files

    def _relative_to_source(self, file_path: Path) -> Path:
        """Convert absolute path to relative path from source."""
        return file_path.relative_to(self.source_path)

    def _relative_to_target(self, file_path: Path) -> Path:
        """Convert absolute path to relative path from target."""
        return file_path.relative_to(self.target_path)

    def discover(self) -> set[SecretWorkItem]:
        """Discover Secret and SopsSecret files and determine required operations.

        Returns:
            Set of SecretWorkItem objects representing required secret operations

        Raises:
            RuntimeError: If both Secret and SopsSecret exist for the same resource
        """
        secrets = set()
        src_secrets = {
            self._relative_to_source(f)
            for f in self.source_files
            if f.name.startswith("Secret-")
        }
        target_secrets = {
            self._relative_to_target(f)
            for f in self.target_files
            if f.name.startswith("SopsSecret-")
        }

        # Process source secrets (Secret-*)
        for src in src_secrets:
            dest = src.parent / ("SopsSecret-" + src.name[7:])
            if (self.source_path / dest).exists():
                raise RuntimeError(
                    f"Resource collision detected: Both Secret and SopsSecret exist for the same resource\n"
                    f"  Secret:     {self.source_path / src}\n"
                    f"  SopsSecret: {self.source_path / dest}\n"
                    f"Please remove one of these resources to resolve the conflict."
                )
            op = (
                SecretOperation.UPDATE
                if (self.target_path / dest).exists()
                else SecretOperation.CREATE
            )
            secrets.add(SecretWorkItem(src, dest, op))

        # Process target secrets (SopsSecret-*)
        for dest in target_secrets:
            src = dest.parent / ("Secret-" + dest.name[11:])
            if (self.source_path / dest).exists():
                # SopsSecret exists in source
                if (self.source_path / src).exists():
                    raise RuntimeError(
                        f"Resource collision detected: Both Secret and SopsSecret exist for the same resource\n"
                        f"  Secret:     {self.source_path / src}\n"
                        f"  SopsSecret: {self.source_path / dest}\n"
                        f"Please remove one of these resources to resolve the conflict."
                    )
                secrets.add(SecretWorkItem(None, dest, SecretOperation.NOOP))
            elif (self.source_path / src).exists():
                secrets.add(SecretWorkItem(src, dest, SecretOperation.UPDATE))
            else:
                secrets.add(SecretWorkItem(None, dest, SecretOperation.DELETE))

        return secrets
