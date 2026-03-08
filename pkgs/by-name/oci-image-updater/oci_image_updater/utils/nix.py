"""Nix utilities."""

import json
import logging
import platform
from pathlib import Path
from typing import Any, Dict, Optional

from .process import ProcessUtils


class NixUtils:
    """Utility class for Nix operations."""

    @staticmethod
    def eval(flake_ref: str, attr: str, json_output: bool = True) -> str:
        """Evaluate a nix flake attribute.

        Args:
            flake_ref: Flake reference (e.g., ".", "/path/to/flake")
            attr: Attribute path to evaluate (e.g., "imagesMetadata")
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
    def get_images_metadata(flake_ref: str) -> Dict[str, Dict[str, Any]]:
        """Get all images metadata from the flake.

        Args:
            flake_ref: Flake reference (e.g., ".", "/path/to/flake")

        Returns:
            Nested dict of image metadata, keyed by path components
        """
        try:
            output = NixUtils.eval(flake_ref, "imagesMetadata", json_output=True)
            return json.loads(output)
        except Exception as e:
            logging.error(f"Failed to get images metadata: {e}")
            return {}

    @staticmethod
    def prefetch_docker(
        image_name: str,
        image_tag: str,
        arch: str,
        os: str,
    ) -> Dict[str, str]:
        """Prefetch a docker image and get its hash information.

        Args:
            image_name: Image name (e.g., "linuxserver/radarr")
            image_tag: Image tag (e.g., "nightly")
            arch: Architecture (e.g., "amd64")
            os: Operating system (e.g., "linux")

        Returns:
            Dict with imageName, imageDigest, hash, finalImageName, finalImageTag
        """
        cmd = [
            "nix-prefetch-docker",
            "--image-name",
            image_name,
            "--image-tag",
            image_tag,
            "--arch",
            arch,
            "--os",
            os,
        ]
        output = ProcessUtils.run(cmd)

        # Find the Nix attribute set (the part between { and })
        lines = output.split("\n")
        in_attrset = False
        attrset_lines = []

        for line in lines:
            stripped = line.strip()
            if stripped == "{":
                in_attrset = True
                continue
            elif stripped == "}" and in_attrset:
                break
            elif in_attrset:
                attrset_lines.append(stripped)

        # Parse the attribute set
        result = {}
        for line in attrset_lines:
            # Skip empty lines
            if not line:
                continue
            # Remove trailing semicolon and parse key = "value"
            line = line.rstrip(";").strip()
            if "=" in line:
                key, value = line.split("=", 1)
                key = key.strip()
                value = value.strip().strip('"')
                result[key] = value

        if "imageDigest" not in result or "hash" not in result:
            raise RuntimeError(
                f"Failed to parse nix-prefetch-docker output. "
                f"Missing required fields. Got: {result}\nOutput: {output}"
            )

        return result

    @staticmethod
    def get_image_store_path(
        flake_ref: str,
        image_path: list[str],
        system: Optional[str] = None,
    ) -> Path:
        """Get the expected store path for an image without building it.

        Args:
            flake_ref: Flake reference (e.g., ".")
            image_path: Path components (e.g., ["linuxserver", "radarr"])
            system: System platform (auto-detected if not specified)

        Returns:
            Expected Nix store path for the image
        """
        if system is None:
            system = NixUtils.get_system()

        attr = f"imagesDerivations.{system}.{'.'.join(image_path)}.outPath"

        cmd = [
            "nix",
            "eval",
            "--raw",
            "--extra-experimental-features",
            "nix-command",
            "--extra-experimental-features",
            "flakes",
            f"{flake_ref}#{attr}",
        ]
        output = ProcessUtils.run(cmd)
        return Path(output.strip())

    @staticmethod
    def build_image(
        flake_ref: str,
        image_path: list[str],
        system: Optional[str] = None,
    ) -> Path:
        """Build an image derivation and return its store path.

        Args:
            flake_ref: Flake reference (e.g., ".")
            image_path: Path components (e.g., ["linuxserver", "radarr"])
            system: System platform (auto-detected if not specified)

        Returns:
            Path to the built image tarball in the Nix store
        """
        if system is None:
            system = NixUtils.get_system()

        attr = f"imagesDerivations.{system}.{'.'.join(image_path)}"

        cmd = [
            "nix",
            "build",
            "--extra-experimental-features",
            "nix-command",
            "--extra-experimental-features",
            "flakes",
            "--print-out-paths",
            "--no-link",
            f"{flake_ref}#{attr}",
        ]
        output = ProcessUtils.run(cmd)
        return Path(output.strip())
