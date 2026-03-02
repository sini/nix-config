"""Secret discovery, processing, and management."""

import logging
import os
from pathlib import Path
from typing import Any, Dict, List

import yaml

from .models import SecretOperation, SecretWorkItem
from .secret_converter import PLAINTEXT_SHA_ANNOTATION, SecretConverter
from .utils import ProcessUtils, YAMLProcessor


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


class SecretProcessor:
    """Processes secret operations (encryption, updates, etc)."""

    def __init__(
        self,
        source_path: Path,
        target_path: Path,
        git_root: Path,
        dry_run: bool = False,
    ):
        """Initialize SecretProcessor.

        Args:
            source_path: Source directory path
            target_path: Target directory path
            git_root: Git repository root path
            dry_run: If True, don't write changes to disk
        """
        self.source_path = source_path
        self.target_path = target_path
        self.git_root = git_root
        self.dry_run = dry_run

    def _resolve_vals(self, file_path: Path) -> str:
        """Resolve vals templates in a file.

        Args:
            file_path: Relative path to file from source

        Returns:
            File contents with vals templates resolved
        """
        with open(self.source_path / file_path, "r") as f:
            return ProcessUtils.run(
                ["vals", "eval"],
                cwd=self.git_root,
                input_text=f.read(),
            )

    def _sops_encrypt_document(
        self,
        contents: Dict[str, Any],
        target_file_path: Path,
    ) -> Dict[str, Any]:
        """Encrypt a document using SOPS.

        Args:
            contents: Document to encrypt
            target_file_path: Target file path (used for SOPS config lookup)

        Returns:
            Encrypted document
        """
        raw_yaml = yaml.safe_dump(contents, sort_keys=True)
        result = ProcessUtils.run(
            [
                "sops",
                "--config",
                str(self.git_root / ".sops.yaml"),
                "--filename-override",
                str(target_file_path),
                "--input-type",
                "yaml",
                "--output-type",
                "yaml",
                "-e",
                "/dev/stdin",
            ],
            cwd=self.git_root,
            input_text=raw_yaml,
        )
        return yaml.safe_load(result)

    def process_create(self, work_item: SecretWorkItem) -> None:
        """Process CREATE operation for a secret.

        Args:
            work_item: Work item describing the operation
        """
        enriched = self._resolve_vals(work_item.source_path)
        sha256 = YAMLProcessor.sha256_hex(enriched)
        documents = YAMLProcessor.load_documents(enriched)
        sopssecret_documents = [
            SecretConverter.convert_to_sopssecret(doc, sha256) for doc in documents
        ]
        encrypted_sops = [
            self._sops_encrypt_document(doc, self.target_path / work_item.target_path)
            for doc in sopssecret_documents
        ]
        output_document = YAMLProcessor.dump_documents(encrypted_sops)

        target_file = self.target_path / work_item.target_path
        target_file.parent.mkdir(parents=True, exist_ok=True)

        if self.dry_run:
            logging.debug(f"[DRY RUN] Would create secret: {work_item.target_path}")
        else:
            with open(target_file, "w") as f:
                f.write(output_document)
            os.chmod(target_file, 0o644)
            logging.debug(f"Created secret: {work_item.target_path}")

    def process_update(self, work_item: SecretWorkItem) -> None:
        """Process UPDATE operation for a secret.

        Args:
            work_item: Work item describing the operation
        """
        target_file_path = self.target_path / work_item.target_path

        # Read existing target file to check if update is needed
        with open(target_file_path, "r") as f:
            existing_content = f.read()
        existing_docs = YAMLProcessor.load_documents(existing_content)

        # Compute hash of current source content
        enriched = self._resolve_vals(work_item.source_path)
        sha256 = YAMLProcessor.sha256_hex(enriched)

        # Check if the plaintext has changed by comparing hashes
        existing_hash = None
        if existing_docs and "metadata" in existing_docs[0]:
            existing_hash = (
                existing_docs[0]
                .get("metadata", {})
                .get("annotations", {})
                .get(PLAINTEXT_SHA_ANNOTATION)
            )

        if existing_hash == sha256:
            # No changes needed, skip update
            logging.debug(f"Secret unchanged (hash match): {work_item.target_path}")
        else:
            # Hash mismatch or missing, proceed with update
            documents = YAMLProcessor.load_documents(enriched)
            sopssecret_documents = [
                SecretConverter.convert_to_sopssecret(doc, sha256) for doc in documents
            ]
            encrypted_sops = [
                self._sops_encrypt_document(
                    doc, self.target_path / work_item.target_path
                )
                for doc in sopssecret_documents
            ]
            output_document = YAMLProcessor.dump_documents(encrypted_sops)

            if self.dry_run:
                logging.debug(f"[DRY RUN] Would update secret: {work_item.target_path}")
            else:
                with open(target_file_path, "w") as f:
                    f.write(output_document)
                os.chmod(target_file_path, 0o644)
                logging.debug(f"Updated secret: {work_item.target_path}")

    def process_delete(self, work_item: SecretWorkItem) -> None:
        """Process DELETE operation for a secret.

        Args:
            work_item: Work item describing the operation
        """
        target_file = self.target_path / work_item.target_path
        if target_file.exists() and target_file.is_file():
            if self.dry_run:
                logging.debug(f"[DRY RUN] Would delete: {work_item.target_path}")
            else:
                target_file.unlink()
                logging.debug(f"Delete: {work_item.target_path}")


class SecretManager:
    """Manages secret discovery, conversion, and encryption for environments."""

    def __init__(
        self,
        source_path: Path,
        target_path: Path,
        source_files: List[Path],
        target_files: List[Path],
        git_root: Path,
        dry_run: bool = False,
    ):
        """Initialize SecretManager.

        Args:
            source_path: Source directory path
            target_path: Target directory path
            source_files: List of all source files
            target_files: List of all target files
            git_root: Git repository root path
            dry_run: If True, don't write changes to disk
        """
        self.source_path = source_path
        self.target_path = target_path
        self.git_root = git_root
        self.dry_run = dry_run

        # Initialize discovery and processor
        self.discovery = SecretDiscovery(
            source_path, target_path, source_files, target_files
        )
        self.processor = SecretProcessor(source_path, target_path, git_root, dry_run)

        # Discover secrets
        self.work_items = self.discovery.discover()

    def process_all(self) -> None:
        """Process all discovered secrets."""
        for work_item in self.work_items:
            logging.debug(f"Processing secret: {work_item}")
            match work_item.op:
                case SecretOperation.CREATE:
                    self.processor.process_create(work_item)
                case SecretOperation.UPDATE:
                    self.processor.process_update(work_item)
                case SecretOperation.DELETE:
                    self.processor.process_delete(work_item)
                case SecretOperation.NOOP:
                    # TODO: Optionally verify encryption keys...
                    pass

    def is_secret_file(
        self,
        relative_path: Path,
        target_only: bool = False,
    ) -> bool:
        """Check if a file is managed as a secret.

        Args:
            relative_path: Relative path to check
            target_only: If True, only check target paths

        Returns:
            True if file is managed as a secret
        """
        for work_item in self.work_items:
            if work_item.op == SecretOperation.NOOP:
                continue
            if work_item.target_path == relative_path:
                return True
            if not target_only and work_item.source_path == relative_path:
                return True
        return False
