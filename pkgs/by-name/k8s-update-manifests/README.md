# k8s-update-manifests

A Python tool for synchronizing Kubernetes manifests from nixidy environment builds to target directories, with support for secret conversion and encryption using SOPS.

## Overview

This package automates the process of:
- Building nixidy environment packages from a Nix flake
- Synchronizing manifest files from build output to target directories
- Converting Kubernetes `Secret` resources to encrypted `SopsSecret` resources
- Managing file lifecycle (create, update, delete operations)
- Resolving vals templates in secrets before encryption

## Installation

This package is built with Nix and is available as a flake package:

```bash
nix build .#k8s-update-manifests
```

## Usage

### Basic Usage

Process all environments in the current flake:

```bash
k8s-update-manifests
```

### Common Options

```bash
# Process specific environment(s)
k8s-update-manifests --env production --env staging

# Dry run mode (show what would change)
k8s-update-manifests --dry-run

# Skip secret processing
k8s-update-manifests --skip-secrets

# Verbose logging
k8s-update-manifests --verbose

# Use custom git root
k8s-update-manifests --git-root /path/to/repo

# Use specific flake reference
k8s-update-manifests --flake /path/to/flake
```

## Architecture

The package is organized into focused modules, with each class in its own file for better maintainability:

```
k8s_update_manifests/
├── models/           # Data models
├── utils/            # Utility classes
├── secrets/          # Secret management
├── environment/      # Environment synchronization
└── sync/             # File synchronization
```

### Component Overview

#### Models (`models/`)

Data models and enumerations used throughout the application:

- **`SecretOperation`** (`secret_operation.py`): Enum for secret operations (CREATE, UPDATE, DELETE, NOOP)
- **`SecretWorkItem`** (`secret_work_item.py`): Represents a secret file operation to be performed
- **`EnvironmentMetadata`** (`environment_metadata.py`): Metadata for nixidy environments (name, repository, branch, output path)

#### Utilities (`utils/`)

General-purpose utility classes:

- **`ProcessUtils`** (`process.py`): Subprocess execution wrapper with error handling
- **`YAMLProcessor`** (`yaml_processor.py`): YAML parsing, serialization, and hashing utilities
- **`GitUtils`** (`git.py`): Git repository operations (get root directory)
- **`NixUtils`** (`nix.py`): Nix operations (eval, build, environment discovery, metadata retrieval)

#### Secrets (`secrets/`)

Secret discovery, conversion, and encryption:

- **`constants.py`**: Shared constants (PLAINTEXT_SHA_ANNOTATION)
- **`SecretDiscovery`** (`discovery.py`): Discovers Secret/SopsSecret files and determines required operations
- **`SecretProcessor`** (`processor.py`): Processes secret operations (vals resolution, SOPS encryption)
- **`SecretConverter`** (`converter.py`): Converts Kubernetes Secrets to SopsSecrets format
- **`SecretManager`** (`manager.py`): Orchestrates secret discovery and processing

#### Environment (`environment/`)

Environment synchronization management:

- **`FileSystemScanner`** (`scanner.py`): Scans directories for files and subdirectories
- **`PathConverter`** (`path_converter.py`): Converts between absolute and relative paths
- **`EnvironmentManager`** (`manager.py`): Main orchestrator for environment synchronization

#### Sync (`sync/`)

File and directory synchronization:

- **`FileSync`** (`file_sync.py`): Handles file/directory operations (copy, update, delete, diff generation)

## Workflow

1. **Discovery**: Discover available nixidy environments from the flake
2. **Build**: Build the environment package using Nix
3. **Scan**: Scan both source (built package) and target directories
4. **Secret Discovery**: Identify secrets that need processing
5. **Diff Calculation**: Determine which files need to be created, updated, or deleted
6. **Synchronization**: Apply file changes in the correct order:
   - Delete obsolete files/directories
   - Create new directories
   - Copy new files
   - Update modified files
7. **Secret Processing**: Convert and encrypt secrets using SOPS
8. **Summary**: Report statistics on operations performed

## Secret Handling

### Secret Conversion

The tool converts Kubernetes `Secret` resources to `SopsSecret` resources:

1. **Source**: `Secret-*.yaml` files in the nixidy build output
2. **Target**: `SopsSecret-*.yaml` files in the target directory
3. **Process**:
   - Resolve vals templates (e.g., `ref+awssecrets://...`)
   - Convert to SopsSecret format (splits ArgoCD/K8s annotations)
   - Encrypt using SOPS with repository's `.sops.yaml` configuration
   - Add plaintext SHA256 hash annotation for change detection

### Smart Updates

Secrets are only re-encrypted when the plaintext content changes, determined by comparing SHA256 hashes stored in annotations. This prevents unnecessary re-encryption and minimizes git churn.

## Dependencies

- **Python 3.11+**: Modern Python with match/case support
- **nix**: For building environment packages
- **vals**: For resolving secret references
- **sops**: For encrypting secrets
- **git**: For repository operations
- **PyYAML**: For YAML processing

## Development

### Project Structure

Each class is in its own file, making it easy to locate and modify specific functionality. Subpackages group related classes:

- `models/` - Domain models
- `utils/` - Cross-cutting utilities
- `secrets/` - Secret-specific logic
- `environment/` - Environment management
- `sync/` - File operations

### Adding New Features

1. Create new class in appropriate subpackage directory
2. Update subpackage `__init__.py` to export the class
3. If needed, update main `__init__.py` for public API
4. Import and use in appropriate manager classes

### Code Style

- Black formatting (line length 88)
- Type hints for all function parameters and return values
- Docstrings using Google style
- One class per file (except small related items like constants)

## License

This package is part of the nix-config repository.
