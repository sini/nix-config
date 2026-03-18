# oci-image-updater

A Python tool for tracking and automatically updating OCI container image
metadata in Nix flakes.

## Overview

This package automates the process of:

- Initializing new image metadata files with current digest and hash
- Checking remote registries for image updates using skopeo (efficient, no
  downloads)
- Fetching and hashing updated images using nix-prefetch-docker
- Updating image metadata files automatically
- Optionally committing changes to git

## Installation

This package is built with Nix and is available as a flake package:

```bash
nix build .#oci-image-updater
```

Or run directly:

```bash
nix run .#oci-image-updater -- --help
```

## Usage

### Initialize a New Image

Create a new image metadata file:

```bash
oci-image-updater init \
  --image-name linuxserver/radarr \
  --image-tag nightly \
  --arch amd64 \
  --os linux
```

This will:

1. Fetch the image from the registry
1. Calculate the digest and Nix hash
1. Create `images/linuxserver/radarr/default.nix` with the metadata

#### Pinning Images

To prevent an image from being automatically updated, use the `--pinned` flag:

```bash
oci-image-updater init \
  --image-name linuxserver/special \
  --image-tag v1.2.3 \
  --arch amd64 \
  --os linux \
  --pinned
```

Pinned images are skipped during `update-all` and `check-all` operations. You
can also manually set `pinned = true` in existing image metadata files.

### Update All Images

Check all images and update those that have changed (skips pinned images):

```bash
# Dry run (show what would change)
oci-image-updater update-all --dry-run

# Update all images
oci-image-updater update-all

# Update and commit changes
oci-image-updater update-all --commit

# Verbose logging
oci-image-updater update-all --verbose
```

### Check for Updates

Check which images have updates available without applying them (skips pinned
images):

```bash
oci-image-updater check-all
```

### Get Store Paths

Get the Nix store path for a specific image without building it:

```bash
oci-image-updater list-path linuxserver/radarr
# Output: /nix/store/...-docker-image-linuxserver-radarr-nightly.tar
```

Get store paths for all images (outputs JSON):

```bash
oci-image-updater list-paths
# Output (JSON):
# [
#   {
#     "image": "linuxserver/lidarr",
#     "path": "/nix/store/...-docker-image-linuxserver-lidarr-latest.tar"
#   },
#   {
#     "image": "linuxserver/radarr",
#     "path": "/nix/store/...-docker-image-linuxserver-radarr-nightly.tar"
#   }
# ]
```

### Build Images

Build a specific image to populate the local Nix store:

```bash
oci-image-updater build-image linuxserver/radarr
# Builds and outputs the store path
```

Build all images to populate the local Nix store:

```bash
oci-image-updater build-images
# Builds all images and shows summary
```

These build commands are useful for:

- Pre-populating the store before publishing to remote caches
- Ensuring images are available locally for deployment
- Copying images to other systems

## Architecture

The package is organized into focused modules:

```
oci_image_updater/
├── models/           # Data models (ImageMetadata, UpdateOperation)
├── utils/            # Utility classes (ProcessUtils, NixUtils, GitUtils)
├── images/           # Image logic (discovery, updater, manager)
├── commands/         # CLI command handlers
│   ├── init.py      # Initialize new images
│   ├── update.py    # Update and check commands
│   ├── paths.py     # Path listing commands
│   ├── build.py     # Build commands
│   └── common.py    # Shared utilities
├── __init__.py       # Package exports
└── __main__.py       # CLI argument parsing and routing
```

### Component Overview

#### Models (`models/`)

- **`ImageMetadata`**: Represents image metadata (name, tag, digest, hash,
  platform)
- **`UpdateOperation`**: Represents an update operation result

#### Utilities (`utils/`)

- **`ProcessUtils`**: Subprocess execution wrapper with error handling
- **`NixUtils`**: Nix operations (eval, prefetch-docker, build, get paths)
- **`GitUtils`**: Git repository operations (get root, add, commit)

#### Images (`images/`)

- **`ImageDiscovery`**: Discovers images from flake metadata
- **`ImageUpdater`**: Updates individual images (check digest, fetch, write
  file)
- **`ImageManager`**: Orchestrates discovery and updates for all images

#### Commands (`commands/`)

- **`init.py`**: Initialize new image metadata files
- **`update.py`**: Update all images and check for updates
- **`paths.py`**: List store paths for images
- **`build.py`**: Build images to populate the store
- **`common.py`**: Shared utilities (logging, git root validation)

## Workflow

1. **Discovery**: Query flake for `imagesMetadata`
1. **Check**: For each image, use skopeo to check remote digest (fast, no
   download)
1. **Compare**: If digest differs, image needs updating
1. **Fetch**: Use nix-prefetch-docker to download and hash the image
1. **Update**: Write new metadata to `default.nix` file
1. **Commit**: Optionally commit changes to git

## Image Metadata Format

Each image is defined in `images/<namespace>/<name>/default.nix`:

```nix
{
  imageName = "linuxserver/radarr";
  imageTag = "nightly";
  imageDigest = "sha256:eddff691c5894288fc97bcb70ff9c3fb0bb9664cec8c2760f212edcde99f2fed";
  imageHash = "sha256-QUjZa92kZkWWNZY5KqG4Z4UgWVA7GifaF2pE/DdzQe4=";
  arch = "amd64";
  os = "linux";
  pinned = false;  # Set to true to prevent automatic updates
}
```

## Integration with Flake

Images are automatically discovered via the `imagesMetadata` flake output:

```bash
# Get all images metadata
nix eval .#imagesMetadata --json

# Get specific image
nix eval .#imagesMetadata.linuxserver.radarr --json
```

## Dependencies

- **Python 3.11+**: Modern Python with type hints
- **nix**: For flake evaluation
- **skopeo**: For efficient remote image inspection
- **nix-prefetch-docker**: For fetching and hashing images
- **git**: For repository operations

## Development

### Project Structure

Each class is in its own file, making it easy to locate and modify specific
functionality:

- `models/` - Domain models
- `utils/` - Cross-cutting utilities
- `images/` - Image-specific logic

### Adding New Features

1. Create new class in appropriate subpackage directory
1. Update subpackage `__init__.py` to export the class
1. Update main `__init__.py` for public API if needed
1. Import and use in appropriate manager classes

### Code Style

- Type hints for all function parameters and return values
- Docstrings using Google style
- One class per file
- Clean separation of concerns

## Automation

This tool is designed to be run automatically via GitHub Actions or cron:

```bash
# Run nightly
oci-image-updater update-all --commit
```

This will check all images, update any that have changed, and commit the
results.

## Comparison to nix-prefetch-docker

While `nix-prefetch-docker` is great for fetching a single image, this tool:

- Tracks multiple images in a structured way
- Only downloads when digest changes (using skopeo for checks)
- Automatically updates metadata files
- Integrates with git for change tracking
- Designed for automation

## License

This package is part of the nix-config repository.
