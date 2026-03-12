"""Nix utilities."""

import json
import logging
import platform
from pathlib import Path
from typing import List, Optional

from ..models import EnvironmentMetadata
from .process import ProcessUtils


class NixUtils:
    """Utility class for Nix operations."""

    @staticmethod
    def eval(flake_ref: str, attr: str, json_output: bool = True) -> str:
        """Evaluate a nix flake attribute.

        Args:
            flake_ref: Flake reference (e.g., ".", "/path/to/flake")
            attr: Attribute path to evaluate (e.g., "nixidyEnvs.x86_64-linux")
            json_output: Whether to use --json flag

        Returns:
            Output from nix eval command
        """
        cmd = [
            "nix",
            "eval",
            "--extra-experimental-features",
            "nix-command",
            "--extra-experimental-features",
            "flakes",
        ]
        if json_output:
            cmd.append("--json")
        cmd.append(f"{flake_ref}#{attr}")
        return ProcessUtils.run(cmd)

    @staticmethod
    def build(
        flake_ref: str,
        attr: str,
        out_link: Optional[Path] = None,
    ) -> Path:
        """Build a nix flake attribute using nix-fast-build.

        Args:
            flake_ref: Flake reference (e.g., ".", "/path/to/flake")
            attr: Attribute path to build (e.g., "nixidyEnvs.x86_64-linux.prod.environmentPackage")
            out_link: Optional path for result symlink (Note: nix-fast-build doesn't support out-link)

        Returns:
            Path to the built package
        """
        cmd = [
            "nix-fast-build",
            "--skip-cached",
            "--no-nom",
            "--no-link",
            "--option",
            "accept-flake-config",
            "true",
            "-f",
            f"{flake_ref}#{attr}",
        ]

        logging.debug(f"Running: {' '.join(cmd)}")
        output = ProcessUtils.run(cmd)

        # nix-fast-build outputs build information followed by the store path on the last line
        lines = output.strip().splitlines()
        if not lines:
            raise RuntimeError(
                f"nix-fast-build produced no output for {flake_ref}#{attr}"
            )

        store_path_str = lines[-1].strip()
        logging.debug(
            f"nix-fast-build output ({len(lines)} lines), store path: {store_path_str}"
        )

        # Validate that the last line looks like a store path
        if not store_path_str.startswith("/nix/store/"):
            logging.error(f"Full nix-fast-build output:\n{output}")
            raise RuntimeError(
                f"Expected store path, got: {store_path_str}\n"
                f"Full output has {len(lines)} lines"
            )

        store_path = Path(store_path_str)

        # Create out_link if requested (handled manually instead of using --out-link)
        if out_link:
            if out_link.exists() or out_link.is_symlink():
                out_link.unlink()
            out_link.symlink_to(store_path)
            logging.debug(f"Created symlink: {out_link} -> {store_path}")

        return store_path

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
    def discover_environments(
        flake_ref: str,
        system: Optional[str] = None,
    ) -> List[str]:
        """Discover available nixidy environments from the flake.

        Args:
            flake_ref: Flake reference (e.g., ".", "/path/to/flake")
            system: System platform (auto-detected if not specified)

        Returns:
            List of environment names
        """
        if system is None:
            system = NixUtils.get_system()

        try:
            # Use --apply to extract attribute names without evaluating the full attrset
            # This avoids trying to convert functions to JSON
            cmd = [
                "nix",
                "eval",
                "--extra-experimental-features",
                "nix-command",
                "--extra-experimental-features",
                "flakes",
                "--json",
                "--apply",
                "envs: builtins.attrNames envs",
                f"{flake_ref}#nixidyEnvs.{system}",
            ]
            output = ProcessUtils.run(cmd)
            return json.loads(output)
        except Exception as e:
            logging.error(f"Failed to discover environments: {e}")
            return []

    @staticmethod
    def get_environment_metadata(
        flake_ref: str,
        env: str,
        system: Optional[str] = None,
    ) -> EnvironmentMetadata:
        """Get metadata for a specific nixidy environment.

        Args:
            flake_ref: Flake reference (e.g., ".", "/path/to/flake")
            env: Environment name
            system: System platform (auto-detected if not specified)

        Returns:
            EnvironmentMetadata object
        """
        if system is None:
            system = NixUtils.get_system()

        # Evaluate the nixidy.target configuration
        target_json = NixUtils.eval(
            flake_ref,
            f"nixidyEnvs.{system}.{env}.config.nixidy.target",
            json_output=True,
        )
        target_data = json.loads(target_json)

        return EnvironmentMetadata(
            name=env,
            repository=target_data["repository"],
            branch=target_data["branch"],
            output_path=Path(target_data["rootPath"]),
        )

    @staticmethod
    def build_environment_package(
        flake_ref: str,
        env: str,
        system: Optional[str] = None,
    ) -> Path:
        """Build the environmentPackage for a nixidy environment.

        Args:
            flake_ref: Flake reference (e.g., ".", "/path/to/flake")
            env: Environment name
            system: System platform (auto-detected if not specified)

        Returns:
            Path to the built environment package
        """
        if system is None:
            system = NixUtils.get_system()

        return NixUtils.build(
            flake_ref,
            f"nixidyEnvs.{system}.{env}.environmentPackage",
        )
