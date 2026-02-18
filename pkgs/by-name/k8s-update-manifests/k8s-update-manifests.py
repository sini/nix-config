#!/usr/bin/env python3
"""Update Kubernetes manifests for nixidy environments."""

import argparse
import filecmp
import json
import logging
import os
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

# From pyyaml
import yaml

# TODO: Update isindir/sops-secrets-operator to support mac-only-encrypted

# cat kubernetes/generated/manifests/prod/argocd/Secret-argocd-secret.yaml \
# | vals eval \
# | sops --config git_root/.sops.yaml  -filename-override prod/Secret-foo.yaml \
# --input-type yaml --output-type yaml -e /dev/stdin

"""
apiVersion: isindir.github.com/v1alpha3
kind: SopsSecret
metadata:
  name: ${name}
  namespace: namespace
spec:
  secretTemplates:
    - name: ${name}
      type: Opaque
      stringData:
        username: "$username"
        password: "$password"
"""

def run(cmd: List[str], *, cwd: Optional[Path] = None, input_text: Optional[str] = None) -> str:
    """Run a command, return stdout, raise on failure."""
    p = subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        input=input_text,
        text=True,
        capture_output=True,
        check=False,
    )
    if p.returncode != 0:
        raise RuntimeError(
            f"Command failed ({p.returncode}): {' '.join(cmd)}\n"
            f"--- stdout ---\n{p.stdout}\n"
            f"--- stderr ---\n{p.stderr}\n"
        )
    return p.stdout

class SecretConverter(object):
  @staticmethod
  def convertSecretToSopsSecret(secretFilePath):
    name = secretFilePath


@dataclass(frozen=True)
class SecretWorkItem:
  source_path: Path
  target_path: Path

@dataclass(frozen=True)
class EnvironmentMetadata:
  name: str
  repository: str
  branch: str
  output_path: str

class EnvironmentManager:
  sourceFiles = []
  sourceDirs = []
  sourceSecretFiles = []

  targetFiles = []
  targetDirs = []
  targetSecretFiles = []

  environment: EnvironmentMetadata = None

  def __init__(self, source: Path, environment: EnvironmentMetadata, dry_run: bool = False, skip_secrets: bool = False):
    self.source = source
    self.environment = environment
    self.dry_run = dry_run
    self.skip_secrets = skip_secrets
    (self.sourceFiles, self.sourceDirs) = self._scan_path(self.source)
    (self.targetFiles, self.targetDirs) = self._scan_path(self.environment.output_path)
    self.secret_files: List[SecretWorkItem] = []

  @staticmethod
  def _scan_path(path: Path) -> Tuple[List[Path], List[Path]]:
    files: List[Path] = []
    directories: List[Path] = []
    for root, dirs, filenames in path.walk(follow_symlinks=True):
        directories.append(root)
        directories.extend(root / d for d in dirs)
        files.extend(root / f for f in filenames)
    return files, directories
    pass

  def _resource_is_secret(resource: Path) -> bool:
    return f.name.startswith('Secret-') or f.name.startswith('SopsSecret-')

  def _relative_to_source(self, f: Path) -> Path:
    return f.relative_to(self.source)

  def _relative_to_target(self, f: Path) -> Path:
    return f.relative_to(self.environment.output_path)

  def _compare_files(self, sourceFile: Path, destFile: Path):
    # print("Comparing: %s -> %s" % (sourceFile, destFile))
    return not filecmp.cmp(sourceFile, destFile)
    # difflib.unified_diff()

  def _cleanup_files(self, files: set[Path]):
    """Delete files from target directory."""
    for f in files:
      target_file = self.environment.output_path / f
      if target_file.exists() and target_file.is_file():
        if self.dry_run:
          logging.info(f"[DRY RUN] Would delete: {f}")
        else:
          target_file.unlink()
          logging.info(f"Delete: {f}")

  def _compute_file_difference(self):
    src_files = {self._relative_to_source(f) for f in self.sourceFiles}
    target_files = {self._relative_to_target(f) for f in self.targetFiles}
    src_dirs = {self._relative_to_source(d) for d in self.sourceDirs}
    target_dirs = {self._relative_to_target(d) for d in self.targetDirs}

    new_files = src_files - target_files
    new_dirs = src_dirs - target_dirs

    existing_files = src_files & target_files

    updated_files = {f for f in existing_files if self._compare_files(self.source / f, self.environment.output_path / f)}
    unchanged_files =  existing_files - updated_files

    deleted_files = target_files - src_files
    deleted_dirs = target_dirs - src_dirs

    self._cleanup_files(deleted_files)
    self._cleanup_directories(deleted_dirs)
    self._create_directories(new_dirs)
    print("New files:")
    self._copy_files(new_files)

    print("Changed files:")
    self._copy_files(updated_files)

    for f in unchanged_files:
      logging.info(f)

  def _copy_files(self, files: set[Path]):
    """Copy files from source to target directory."""
    for f in files:
      source_file = self.source / f
      target_file = self.environment.output_path / f
      shutil.copy2(source_file, target_file)
      print(f"Copied: {f}")

  def _create_directories(self, dirs: set[Path]):
    """Create directories in sorted order (parents before children)."""
    sorted_dirs = sorted(dirs, key=lambda d: (len(d.parts), str(d)))
    for d in sorted_dirs:
      target_dir = self.environment.output_path / d
      if self.dry_run:
        logging.info(f"[DRY RUN] Would create: {d}")
      else:
        target_dir.mkdir(parents=True, exist_ok=True)
        logging.info(f"Created: {d}")

  def _cleanup_directories(self, dirs: set[Path]):
    """Remove directories in reverse sorted order (children before parents)."""
    sorted_dirs = sorted(dirs, key=lambda d: (len(d.parts), str(d)), reverse=True)
    for d in sorted_dirs:
      target_dir = self.environment.output_path / d
      if target_dir.exists() and target_dir.is_dir():
        if self.dry_run:
          logging.info(f"[DRY RUN] Would remove: {d}")
        else:
          target_dir.rmdir()
          logging.info(f"Removed: {d}")


  def print(self):
    logging.info("Hello: " + str(self.source) + " -> " + str(self.environment.output_path))
    self._compute_file_difference()
    # for f in self.sourceSecretFiles:
    #   logging.info(self._relative_to_source(f))




def get_git_root() -> Optional[Path]:
  """Get the root directory of the current git repository.

  Returns:
      Path to the git repository root, or None if not in a git repo.
  """
  try:
    out = run(["git", "rev-parse", "--show-toplevel"], cwd=Path(os.getcwd()))
    return Path(out.strip())
  except Exception:
      return None


def main() -> int:
  """Main entry point."""
  # Configure logging
  logging.basicConfig(
    level=logging.INFO,
    format='%(levelname)s: %(message)s'
  )

  parser = argparse.ArgumentParser(
    description="Update Kubernetes manifests for nixidy environments"
  )
  parser.add_argument(
    "--git-root",
    type=Path,
    help="Git repository root path (auto-detected if not specified)"
  )
  parser.add_argument(
    "--dry-run",
    action="store_true",
    help="Show what would be changed without actually making changes"
  )
  parser.add_argument(
    "--skip-secrets",
    action="store_true",
    help="Exclude secret files from processing"
  )

  args = parser.parse_args()

  # Detect or use specified git repository root
  if args.git_root:
    git_root = args.git_root.resolve()
    if not git_root.exists():
      logging.error(f"specified git root does not exist: {git_root}")
      return 1
  else:
    git_root = get_git_root()
    if git_root is None:
      logging.error("not running from within a git repository")
      return 1

  if args.dry_run:
    logging.info("DRY RUN MODE: No changes will be made")
    logging.info("")

  if args.skip_secrets:
    logging.info("SKIP SECRETS MODE: Secret files will be excluded from processing")
    logging.info("")

  logging.info(f"Git repository root: {git_root}")
  logging.info("")

  # Find the environments directory relative to this script
  script_path = Path(__file__).resolve()
  envs_dir = script_path.parent.parent / "share" / "nixidy-environments"

  if not envs_dir.exists():
    logging.error(f"environments directory not found at {envs_dir}")
    return 1

  # Discover environments from symlinks and metadata
  environments: Dict[str, Tuple[Path, EnvironmentMetadata]] = {}
  for entry in sorted(envs_dir.iterdir()):
    # Look for environment directories (symlinks or directories)
    if entry.is_dir():
      metadata_file = envs_dir / f"{entry.name}.yaml"
      if not metadata_file.exists():
        logging.warning(f"metadata file not found for environment {entry.name}")
        continue

      # Read metadata
      with open(metadata_file, 'r') as f:
        metadata_data = yaml.safe_load(f)
        metadata = EnvironmentMetadata(
          name = metadata_data['name'],
          repository = metadata_data['repository'],
          branch = metadata_data['branch'],
          output_path = git_root / metadata_data['rootPath'].lstrip('./')
        )

      environments[entry.name] = (entry, metadata)

  if not environments:
    logging.error("no environments found")
    return 1

  # Print environment mappings
  for env, (src_path, metadata) in environments.items():
    em = EnvironmentManager(src_path, metadata, dry_run=args.dry_run, skip_secrets=args.skip_secrets)
    em.print()

  return 0

if __name__ == "__main__":
  sys.exit(main())
