"""Secret processing logic."""

import logging
import os
from pathlib import Path
from typing import Any, Dict

import yaml

from ..models import SecretWorkItem
from ..utils import ProcessUtils, YAMLProcessor
from .constants import PLAINTEXT_SHA_ANNOTATION
from .converter import SecretConverter


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
