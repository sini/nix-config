"""YAML processing utilities."""

import hashlib
from typing import Any, Dict, List

import yaml


class YAMLProcessor:
    """Utility class for YAML processing operations."""

    @staticmethod
    def load_documents(text: str) -> List[Dict[str, Any]]:
        """Load YAML documents from text.

        Args:
            text: YAML text containing one or more documents

        Returns:
            List of parsed YAML documents as dictionaries

        Raises:
            ValueError: If a YAML document is not a mapping/object
        """
        docs: List[Dict[str, Any]] = []
        for doc in yaml.safe_load_all(text):
            if doc is None:
                continue
            if not isinstance(doc, dict):
                raise ValueError("YAML document is not a mapping/object")
            docs.append(doc)
        return docs

    @staticmethod
    def dump_documents(docs: List[Dict[str, Any]]) -> str:
        """Dump YAML documents to text.

        Args:
            docs: List of dictionaries to serialize as YAML

        Returns:
            YAML text with documents separated by '---'

        Note:
            Output is stable-ish but should not be relied upon for hashing.
            Use sha256_hex() for content hashing instead.
        """
        return yaml.safe_dump_all(docs, sort_keys=True)

    @staticmethod
    def sha256_hex(text: str) -> str:
        """Calculate SHA256 hash of text.

        Args:
            text: Text to hash

        Returns:
            Hexadecimal SHA256 hash string
        """
        hasher = hashlib.sha256()
        hasher.update(text.encode("utf-8"))
        return hasher.hexdigest()
