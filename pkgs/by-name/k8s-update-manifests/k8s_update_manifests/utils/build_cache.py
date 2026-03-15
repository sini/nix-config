"""Build cache for k8s-update-manifests.

Caches nix build results keyed on a fingerprint of k8s-relevant source files,
so that unrelated flake changes (e.g. editing adb.nix) don't trigger a full
13s nix re-evaluation.
"""

import hashlib
import json
import logging
import time
from pathlib import Path

from .process import ProcessUtils

# Paths that affect nixidy output. Changes outside these paths cannot
# change the k8s manifests, so we skip re-evaluation.
WATCHED_PATHS = [
    # Flake inputs
    "flake.lock",
    "flake.nix",
    # Nixidy build infrastructure
    "modules/flake-parts/nixidy-envs.nix",
    "modules/flake-parts/helm-charts.nix",
    "modules/flake-parts/meta/kubernetes-service-module.nix",
    "modules/flake-parts/meta/environment-options.nix",
    "modules/flake-parts/meta/secrets-paths.nix",
    "modules/flake-parts/meta/host-options.nix",
    "modules/flake-parts/meta/lib-module.nix",
    # Libraries
    "modules/lib/nixidy-env-helpers.nix",
    "modules/lib/kubernetes-service-module-helpers.nix",
    # Kubernetes services and environments
    "modules/kubernetes",
    "modules/environments",
    # Host definitions (referenced by k8s modules)
    "modules/hosts",
    # Repo metadata
    "modules/meta/repo.nix",
    # Helm charts
    "charts",
    # Secrets
    ".secrets",
    ".sops.yaml",
]

CACHE_FILENAME = ".cache/k8s-update-manifests.json"
CACHE_MAX_AGE_SECONDS = 8 * 60 * 60  # 8 hours


class BuildCache:
    """Cache nix build results keyed on source fingerprint."""

    def __init__(self, git_root: Path):
        self._git_root = git_root
        self._cache_file = git_root / CACHE_FILENAME

    def _compute_fingerprint(self) -> str:
        """Compute a hash of all k8s-relevant source files.

        Uses git to efficiently hash both committed and uncommitted state
        for each watched path.
        """
        parts = []
        for path in WATCHED_PATHS:
            full_path = self._git_root / path
            if not full_path.exists():
                continue

            # Get committed tree/blob hash
            try:
                committed = ProcessUtils.run(
                    ["git", "rev-parse", f"HEAD:{path}"],
                    cwd=self._git_root,
                )
                parts.append(f"{path}:committed:{committed.strip()}")
            except Exception:
                parts.append(f"{path}:committed:none")

            # Get uncommitted changes (staged + unstaged)
            try:
                diff = ProcessUtils.run(
                    ["git", "diff", "HEAD", "--", path],
                    cwd=self._git_root,
                )
                if diff.strip():
                    diff_hash = hashlib.sha256(diff.encode()).hexdigest()
                    parts.append(f"{path}:dirty:{diff_hash}")
            except Exception:
                pass

            # Check for untracked files in directories
            if full_path.is_dir():
                try:
                    untracked = ProcessUtils.run(
                        [
                            "git",
                            "ls-files",
                            "--others",
                            "--exclude-standard",
                            "--",
                            path,
                        ],
                        cwd=self._git_root,
                    )
                    if untracked.strip():
                        untracked_hash = hashlib.sha256(untracked.encode()).hexdigest()
                        parts.append(f"{path}:untracked:{untracked_hash}")
                except Exception:
                    pass

        fingerprint = hashlib.sha256("\n".join(parts).encode()).hexdigest()
        logging.debug(f"Source fingerprint: {fingerprint}")
        return fingerprint

    def _load(self) -> dict | None:
        """Load cache from disk."""
        if not self._cache_file.exists():
            return None
        try:
            with open(self._cache_file) as f:
                return json.load(f)
        except (json.JSONDecodeError, OSError):
            return None

    def _save(self, fingerprint: str, manifest: dict) -> None:
        """Save cache to disk."""
        self._cache_file.parent.mkdir(parents=True, exist_ok=True)
        with open(self._cache_file, "w") as f:
            json.dump(
                {
                    "fingerprint": fingerprint,
                    "manifest": manifest,
                    "timestamp": time.time(),
                },
                f,
            )

    def get(self) -> dict | None:
        """Check cache for a valid hit.

        Returns the manifest dict if cache is valid (fingerprint matches
        and all store paths still exist), otherwise None.
        """
        cache = self._load()
        if cache is None:
            logging.debug("No build cache found")
            return None

        age = time.time() - cache.get("timestamp", 0)
        if age > CACHE_MAX_AGE_SECONDS:
            logging.debug(
                f"Build cache expired ({age / 3600:.1f}h old), will re-evaluate"
            )
            return None

        fingerprint = self._compute_fingerprint()
        if cache.get("fingerprint") != fingerprint:
            logging.debug("Build cache fingerprint mismatch, will re-evaluate")
            return None

        # Verify all cached store paths still exist
        manifest = cache.get("manifest", {})
        for env_name, data in manifest.items():
            pkg_path = Path(data["packagePath"])
            if not pkg_path.exists():
                logging.debug(f"Cached store path missing for {env_name}: {pkg_path}")
                return None

        logging.info("Using cached build (no k8s-relevant changes detected)")
        return manifest

    def put(self, manifest: dict) -> None:
        """Store build results in cache."""
        fingerprint = self._compute_fingerprint()
        self._save(fingerprint, manifest)
        logging.debug("Build cache updated")
