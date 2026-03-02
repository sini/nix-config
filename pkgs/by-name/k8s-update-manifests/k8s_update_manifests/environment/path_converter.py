"""Path conversion utilities."""

from pathlib import Path


class PathConverter:
    """Utility for converting between absolute and relative paths."""

    def __init__(self, base_path: Path):
        """Initialize PathConverter.

        Args:
            base_path: Base path for relative conversions
        """
        self.base_path = base_path

    def to_relative(self, file_path: Path) -> Path:
        """Convert absolute path to relative path from base.

        Args:
            file_path: Absolute path to convert

        Returns:
            Relative path from base
        """
        return file_path.relative_to(self.base_path)
