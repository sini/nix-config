"""Update Kubernetes manifests for nixidy environments.

This package provides tools for synchronizing Kubernetes manifests from nixidy
environment builds to target directories, with support for secret conversion
and encryption using SOPS.
"""

__version__ = "1.0.0"

from .environment_manager import EnvironmentManager
from .file_sync import FileSync
from .models import EnvironmentMetadata, SecretOperation, SecretWorkItem
from .secret_converter import SecretConverter
from .secret_manager import SecretManager
from .utils import GitUtils, NixUtils, ProcessUtils, YAMLProcessor

__all__ = [
    "EnvironmentManager",
    "EnvironmentMetadata",
    "FileSync",
    "GitUtils",
    "NixUtils",
    "ProcessUtils",
    "SecretConverter",
    "SecretManager",
    "SecretOperation",
    "SecretWorkItem",
    "YAMLProcessor",
]
