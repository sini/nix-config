"""Nix utilities."""

import json
import logging
import platform
from pathlib import Path
from typing import Optional

from ..models import EnvironmentMetadata
from .process import ProcessUtils


class NixUtils:
    """Utility class for Nix operations."""

    @staticmethod
    def build(
        flake_ref: str,
        attr: str,
    ) -> Path:
        """Build a nix flake attribute.

        Args:
            flake_ref: Flake reference (e.g., ".", "/path/to/flake")
            attr: Attribute path to build (e.g., "packages.x86_64-linux.nixidy-all-envs")

        Returns:
            Path to the built store path
        """
        cmd = [
            "nix",
            "build",
            "--extra-experimental-features",
            "nix-command",
            "--extra-experimental-features",
            "flakes",
            "--no-link",
            "--print-out-paths",
            "--option",
            "accept-flake-config",
            "true",
            f"{flake_ref}#{attr}",
        ]

        logging.debug(f"Running: {' '.join(cmd)}")
        output = ProcessUtils.run(cmd)

        store_path_str = output.strip().splitlines()[-1].strip()
        if not store_path_str.startswith("/nix/store/"):
            logging.error(f"Full nix build output:\n{output}")
            raise RuntimeError(f"Expected store path, got: {store_path_str}")

        return Path(store_path_str)

    @staticmethod
    def get_system() -> str:
        """Detect the current system platform.

        Returns:
            System string (e.g., "x86_64-linux", "aarch64-darwin")
        """
        machine = platform.machine()
        system_name = platform.system().lower()

        # Map machine architectures
        arch_map = {
            "x86_64": "x86_64",
            "amd64": "x86_64",
            "arm64": "aarch64",
            "aarch64": "aarch64",
        }

        # Map system names
        os_map = {
            "linux": "linux",
            "darwin": "darwin",
        }

        arch = arch_map.get(machine.lower(), machine)
        os_name = os_map.get(system_name, system_name)

        return f"{arch}-{os_name}"

    @staticmethod
    def parse_manifest(manifest: dict) -> dict[str, tuple["EnvironmentMetadata", Path]]:
        """Parse a manifest dict into environment results.

        Args:
            manifest: Raw manifest dict from nixidy-all-envs

        Returns:
            Dict of env name to (EnvironmentMetadata, Path) tuples
        """
        results = {}
        for env_name, data in manifest.items():
            metadata = EnvironmentMetadata(
                name=env_name,
                repository=data["repository"],
                branch=data["branch"],
                output_path=Path(data["rootPath"]),
            )
            package_path = Path(data["packagePath"])
            results[env_name] = (metadata, package_path)
        return results

    @staticmethod
    def build_all_environments(
        flake_ref: str,
        system: Optional[str] = None,
    ) -> tuple[dict[str, tuple["EnvironmentMetadata", Path]], dict]:
        """Build all environment packages in a single nix evaluation.

        Args:
            flake_ref: Flake reference
            system: System platform (auto-detected if not specified)

        Returns:
            Tuple of (parsed results dict, raw manifest dict)
        """
        if system is None:
            system = NixUtils.get_system()

        all_envs_path = NixUtils.build(
            flake_ref,
            f"packages.{system}.nixidy-all-envs",
        )

        manifest_path = all_envs_path / "manifest.json"
        with open(manifest_path) as f:
            manifest = json.load(f)

        return NixUtils.parse_manifest(manifest), manifest
