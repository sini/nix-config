#!/usr/bin/env python3
"""Update Kubernetes manifests for nixidy environments."""

import argparse
import filecmp
import json
import os
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

  def __init__(self, source: Path, environment: EnvironmentMetadata):
    self.source = source
    self.environment = environment
    self._index_source()
    self._index_target()
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

  def _index_source(self):
    (files, directories) = self._scan_path(self.source)
    self.sourceDirs = directories
    self.sourceFiles = [f for f in files if not f.name.startswith('Secret-')]
    self.sourceSecretFiles = [f for f in files if f.name.startswith('Secret-')]

  def _index_target(self):
    (files, directories) = self._scan_path(self.environment.output_path)
    self.targetDirs = directories
    self.targetFiles = [f for f in files if not f.name.startswith('SopsSecret-')]
    self.targetSecretFiles = [f for f in files if f.name.startswith('SopsSecret-')]

  def _relative_to_source(self, f: Path) -> Path:
    return f.relative_to(self.source)

  def _relative_to_target(self, f: Path) -> Path:
    return f.relative_to(self.environment.output_path)

  def _compare_files(self, sourceFile: Path, destFile: Path):
    # print("Comparing: %s -> %s" % (sourceFile, destFile))
    return not filecmp.cmp(sourceFile, destFile)
    # difflib.unified_diff()

  def _cleanup_files(self, files: set[Path]):
    """Remove files from target directory."""
    for f in files:
      target_file = self.environment.output_path / f
      if target_file.exists() and target_file.is_file():
        target_file.unlink()
        print(f"Removed: {f}")

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

    print("Deleted files:")
    self._cleanup_files(deleted_files)

    print("Deleted directories:")
    self._cleanup_directories(deleted_dirs)

    print("New directories:")
    self._create_directories(new_dirs)

    print("New files:")
    for f in new_files:
      print(f)

    print("Changed files:")
    for f in updated_files:
      print(f)

    print("unchanged files:")
    for f in unchanged_files:
      print(f)

  def _create_directories(self, dirs: set[Path]):
    """Create directories in sorted order (parents before children)."""
    sorted_dirs = sorted(dirs, key=lambda d: (len(d.parts), str(d)))
    for d in sorted_dirs:
      target_dir = self.environment.output_path / d
      target_dir.mkdir(parents=True, exist_ok=True)
      print(f"Created: {d}")

  def _cleanup_directories(self, dirs: set[Path]):
    """Remove directories in reverse sorted order (children before parents)."""
    sorted_dirs = sorted(dirs, key=lambda d: (len(d.parts), str(d)), reverse=True)
    for d in sorted_dirs:
      target_dir = self.environment.output_path / d
      if target_dir.exists() and target_dir.is_dir():
        target_dir.rmdir()
        print(f"Removed: {d}")


  def print(self):
    print("Hello: " + str(self.source) + " -> " + str(self.environment.output_path))
    self._compute_difference()
    # for f in self.sourceSecretFiles:
    #   print(self._relative_to_source(f))




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

  args = parser.parse_args()

  # Detect or use specified git repository root
  if args.git_root:
    git_root = args.git_root.resolve()
    if not git_root.exists():
      print(f"Error: specified git root does not exist: {git_root}", file=sys.stderr)
      return 1
  else:
    git_root = get_git_root()
    if git_root is None:
      print("Error: not running from within a git repository", file=sys.stderr)
      return 1

  print(f"Git repository root: {git_root}")
  print()

  # Find the environments directory relative to this script
  script_path = Path(__file__).resolve()
  envs_dir = script_path.parent.parent / "share" / "nixidy-environments"

  if not envs_dir.exists():
    print(f"Error: environments directory not found at {envs_dir}", file=sys.stderr)
    return 1

  # Discover environments from symlinks and metadata
  environments: Dict[str, Tuple[Path, EnvironmentMetadata]] = {}
  for entry in sorted(envs_dir.iterdir()):
    # Look for environment directories (symlinks or directories)
    if entry.is_dir():
      metadata_file = envs_dir / f"{entry.name}.yaml"
      if not metadata_file.exists():
        print(f"Warning: metadata file not found for environment {entry.name}", file=sys.stderr)
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
    print("Error: no environments found", file=sys.stderr)
    return 1

  # Print environment mappings
  for env, (src_path, metadata) in environments.items():
    em = EnvironmentManager(src_path, metadata)
    em.print()

  return 0

if __name__ == "__main__":
  sys.exit(main())
