"""Converter for transforming Kubernetes Secrets to SopsSecrets."""

import re
from typing import Any, Dict, Optional

# Annotation key for storing plaintext SHA256 hash
PLAINTEXT_SHA_ANNOTATION = "secrets.json64.dev/plaintext-sha256"


class SecretConverter:
    """Handles conversion of Kubernetes Secrets to SopsSecrets."""

    # Regex pattern for ArgoCD and Kubernetes app labels/annotations
    ARGOCD_K8S_PATTERN = r"(argocd\.argoproj\.io|app\.kubernetes\.io)"

    @classmethod
    def filter_metadata(
        cls,
        metadata: Optional[Dict[str, str]],
        include_argocd: bool,
    ) -> Dict[str, str]:
        """Filter metadata by ArgoCD/K8s app annotations pattern.

        Args:
            metadata: Dictionary of labels or annotations to filter
            include_argocd: If True, keep only ArgoCD/K8s patterns; if False, exclude them

        Returns:
            Filtered dictionary
        """
        if not metadata:
            return {}

        result = {}
        regex = re.compile(cls.ARGOCD_K8S_PATTERN)
        for key, value in metadata.items():
            matches = regex.search(key) is not None
            if (include_argocd and matches) or (not include_argocd and not matches):
                result[key] = value
        return result

    @classmethod
    def convert_to_sopssecret(
        cls,
        secret: Dict[str, Any],
        plaintext_hash: str,
    ) -> Dict[str, Any]:
        """Convert a Kubernetes Secret to a SopsSecret.

        Transformation spec:
        - apiVersion: isindir.github.com/v1alpha3
        - kind: SopsSecret
        - Top-level metadata: name, namespace, ArgoCD/K8s annotations & labels only
        - Secret template: includes original type, data, stringData, non-ArgoCD annotations & labels

        Args:
            secret: Kubernetes Secret document
            plaintext_hash: SHA256 hash of plaintext secret content

        Returns:
            SopsSecret document
        """
        metadata = secret.get("metadata", {})

        # Build SopsSecret top-level metadata
        sops_metadata = {
            "name": metadata.get("name"),
            "namespace": metadata.get("namespace"),
        }

        # Filter annotations - only ArgoCD/K8s for top-level
        annotations = cls.filter_metadata(
            metadata.get("annotations"),
            include_argocd=True,
        )
        # Always add plaintext hash annotation
        annotations[PLAINTEXT_SHA_ANNOTATION] = plaintext_hash
        sops_metadata["annotations"] = annotations

        # Filter labels - only ArgoCD/K8s for top-level
        labels = cls.filter_metadata(
            metadata.get("labels"),
            include_argocd=True,
        )
        if labels:
            sops_metadata["labels"] = labels

        # Build secret template
        secret_template = {
            "name": metadata.get("name"),
        }

        # Add type if present
        if "type" in secret:
            secret_template["type"] = secret["type"]

        # Filter labels - exclude ArgoCD/K8s for secret template
        template_labels = cls.filter_metadata(
            metadata.get("labels"),
            include_argocd=False,
        )
        if template_labels:
            secret_template["labels"] = template_labels

        # Filter annotations - exclude ArgoCD/K8s for secret template
        template_annotations = cls.filter_metadata(
            metadata.get("annotations"),
            include_argocd=False,
        )
        if template_annotations:
            secret_template["annotations"] = template_annotations

        # Add stringData if present
        if "stringData" in secret:
            secret_template["stringData"] = secret["stringData"]

        # Add data if present
        if "data" in secret:
            secret_template["data"] = secret["data"]

        # Build final SopsSecret
        return {
            "apiVersion": "isindir.github.com/v1alpha3",
            "kind": "SopsSecret",
            "metadata": sops_metadata,
            "spec": {"secretTemplates": [secret_template]},
        }
