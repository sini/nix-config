#!/usr/bin/env python3
"""Update Kubernetes manifests for nixidy environments."""

import argparse
import difflib
import filecmp
import json
import logging
import os
import shutil
import subprocess
import sys
from dataclasses import dataclass
from enum import Enum
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

class SecretOperation(Enum):
  CREATE = 1
  DELETE = 2
  UPDATE = 3
  NOOP = 4

@dataclass(frozen=True)
class SecretWorkItem:
  source_path: Path
  target_path: Path
  op: SecretOperation

@dataclass(frozen=True)
class EnvironmentMetadata:
  name: str
  repository: str
  branch: str
  output_path: str

class EnvironmentManager:
  sourceFiles: List[Path] = []
  sourceDirs: List[Path] = []
  targetFiles: List[Path] = []
  targetDirs: List[Path] = []

  secretWorkItems: set[SecretWorkItem] = {}

  environment: EnvironmentMetadata = None

  def __init__(self, source: Path, environment: EnvironmentMetadata, dry_run: bool = False, skip_secrets: bool = False):
    self.source = source
    self.environment = environment
    self.dry_run = dry_run
    self.skip_secrets = skip_secrets
    (self.sourceFiles, self.sourceDirs) = self._scan_path(self.source)
    (self.targetFiles, self.targetDirs) = self._scan_path(self.environment.output_path)
    self.secretWorkItems: set[SecretWorkItem] = self._secret_items()

  def _secret_items(self) -> set[SecretWorkItem]:
    secrets = set()
    src_secrets = {self._relative_to_source(f) for f in self.sourceFiles if f.name.startswith("Secret-")}
    target_secrets = {self._relative_to_target(f) for f in self.targetFiles if f.name.startswith("SopsSecret-")}
    for src in src_secrets:
      dest = src.parent /  ("SopsSecret-" + src.name[7:])
      if (self.source/dest).exists():
        raise Exception(
          f"Resource collision detected: Both Secret and SopsSecret exist for the same resource\n"
          f"  Secret:     {self.source / src}\n"
          f"  SopsSecret: {self.source / dest}\n"
          f"Please remove one of these resources to resolve the conflict."
        )
      if (self.environment.output_path / dest).exists():
        op = SecretOperation.UPDATE
      else:
        op = SecretOperation.CREATE
      item = SecretWorkItem(src, dest, op)
      secrets.add(item)
    for dest in target_secrets:
      src =  dest.parent /  ("Secret-" + dest.name[11:])
      if (self.source / dest).exists():
        # SopsSecret resource exists in source...
        if (self.source / src).exists():
          raise Exception(
            f"Resource collision detected: Both Secret and SopsSecret exist for the same resource\n"
            f"  Secret:     {self.source / src}\n"
            f"  SopsSecret: {self.source / dest}\n"
            f"Please remove one of these resources to resolve the conflict."
          )
        src = None
        op = SecretOperation.NOOP
      elif (self.source / src).exists():
        op = SecretOperation.UPDATE
      else:
        op = SecretOperation.DELETE
      item = SecretWorkItem(src, dest, op)
      secrets.add(item)
    return secrets

  def _process_secrets(self):
    for secret in self.secretWorkItems:
      match secret.op:
        case SecretOperation.CREATE:
          print("Create...")
        case SecretOperation.DELETE:
          print("Delete...")
        case SecretOperation.UPDATE:
          print("Update...")
        case SecretOperation.NOOP:
          print("Noop")
          # TODO: Optionally verify encryption keys...
          pass
        case _:
          pass
      logging.debug(f"Processing secret: {secret}")

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

  def _resource_is_secret(self, resource: Path) -> bool:
    for secret in self.secretWorkItems:
      if secret.op == SecretOperation.NOOP:
        continue
      if resource in [secret.source_path, secret.target_path]:
        return True
    return False

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
          logging.debug(f"[DRY RUN] Would delete: {f}")
        else:
          target_file.unlink()
          logging.debug(f"Delete: {f}")

  def _copy_files(self, files: set[Path]):
    """Copy files from source to target directory."""
    for f in files:
      source_file = self.source / f
      target_file = self.environment.output_path / f
      if self.dry_run:
        logging.debug(f"[DRY RUN] Would create file: ./{f}")
      else:
        shutil.copy2(source_file, target_file)
        os.chmod(target_file, 0o644)  # Make writable (since source may be read-only from nix)
        logging.debug(f"Created file: ./{f}")

  def _update_files(self, files: set[Path]):
    """Update files from source to target directory."""
    for f in files:
      source_file = self.source / f
      target_file = self.environment.output_path / f
      diff = self._compute_diff(target_file, source_file)
      if self.dry_run:
        logging.debug(f"[DRY RUN] Would update file: ./{f}")
      else:
        shutil.copy2(source_file, target_file)
        os.chmod(target_file, 0o644)  # Make writable (since source may be read-only from nix)
        logging.debug(f"Updated file: ./{f}")
      if diff:
        logging.debug(f"DIFF:\n{diff}")

  @staticmethod
  def _compute_diff(original: Path, modified:  Path) -> str:
    """Generate a unified diff between two files.

    Args:
      originalFile: Path to the first file (original)
      modifiedFile: Path to the second file (modified)

    Returns:
      Unified diff as a string
    """
    with open(original, 'r') as f1:
      originalLines = f1.readlines()
    with open(modified, 'r') as f2:
      modifiedLines = f2.readlines()

    diff = difflib.unified_diff(
      originalLines,
      modifiedLines,
      fromfile=str(original),
      tofile=str(modified),
      lineterm='\n'
    )

    return ''.join(diff)


  def _create_directories(self, dirs: set[Path]):
    """Create directories in sorted order (parents before children)."""
    sorted_dirs = sorted(dirs, key=lambda d: (len(d.parts), str(d)))
    for d in sorted_dirs:
      target_dir = self.environment.output_path / d
      if self.dry_run:
        logging.debug(f"[DRY RUN] Would create directory: ./{d}")
      else:
        target_dir.mkdir(parents=True, exist_ok=True)
        logging.debug(f"Created directory: ./{d}")

  def _cleanup_directories(self, dirs: set[Path]):
    """Remove directories in reverse sorted order (children before parents)."""
    sorted_dirs = sorted(dirs, key=lambda d: (len(d.parts), str(d)), reverse=True)
    for d in sorted_dirs:
      target_dir = self.environment.output_path / d
      if target_dir.exists() and target_dir.is_dir():
        if self.dry_run:
          logging.debug(f"[DRY RUN] Would remove: ./{d}")
        else:
          target_dir.rmdir()
          logging.debug(f"Removed: ./{d}")

  def update(self):
    """Synchronize target directory with source by computing and applying differences.

    Compares source and target directories to identify:
    - New files/directories to create
    - Existing files that need updates
    - Deleted files/directories to remove

    Then applies changes in the correct order to maintain consistency.
    """
    logging.info(f"Updating environment: {self.environment.name}")
    logging.info(f"Output path: {self.environment.output_path}")


    # Convert absolute paths to relative paths for comparison
    src_files = {self._relative_to_source(f) for f in self.sourceFiles if not self._resource_is_secret(f)}
    target_files = {self._relative_to_target(f) for f in self.targetFiles if not self._resource_is_secret(f)}
    src_dirs = {self._relative_to_source(d) for d in self.sourceDirs}
    target_dirs = {self._relative_to_target(d) for d in self.targetDirs}

    # Identify new files and directories (in source but not in target)
    new_files = src_files - target_files
    new_dirs = src_dirs - target_dirs

    # Identify existing files and check which ones need updates
    existing_files = src_files & target_files
    updated_files = {f for f in existing_files if self._compare_files(self.source / f, self.environment.output_path / f)}
    unchanged_files = existing_files - updated_files

    # Identify deleted files and directories (in target but not in source)
    deleted_files = target_files - src_files
    deleted_dirs = target_dirs - src_dirs


    # Apply changes in order: delete -> create dirs -> copy new -> update existing
    self._cleanup_files(deleted_files)
    self._cleanup_directories(deleted_dirs)
    self._create_directories(new_dirs)
    self._copy_files(new_files)
    self._update_files(updated_files)

    if not self.skip_secrets:
      self._process_secrets()

    # Log summary statistics
    if new_dirs:
      logging.info(f"{len(new_dirs)} director(ies) created")
    if new_files:
      logging.info(f"{len(new_files)} file(s) created")
    if updated_files:
      logging.info(f"{len(updated_files)} file(s) updated")
    if deleted_files:
      logging.info(f"{len(deleted_files)} file(s) deleted")
    if deleted_dirs:
      logging.info(f"{len(deleted_dirs)} director(ies) deleted")
    if unchanged_files:
      logging.info(f"{len(unchanged_files)} file(s) unchanged")




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
  parser.add_argument(
    "--verbose",
    action="store_true",
    help="Enable debug logging"
  )

  args = parser.parse_args()

  # Configure logging based on debug flag
  logging.basicConfig(
    level=logging.DEBUG if (args.dry_run or args.verbose) else logging.INFO,
    format='%(levelname)s: %(message)s'
  )

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
    logging.error("No environments found")
    return 1

  for env, (src_path, metadata) in environments.items():
    em = EnvironmentManager(src_path, metadata, dry_run=args.dry_run, skip_secrets=args.skip_secrets)
    em.update()

  return 0

if __name__ == "__main__":
  sys.exit(main())
