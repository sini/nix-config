# OCI Image Auto-Update System Design

## Overview

This document describes the design and implementation of an OCI container image
auto-update system, similar to the existing helm chart auto-update
functionality.

**Status**: ✅ **Phase 1 Complete and Working** - The core system is fully
implemented, tested, and operational.

## Objectives

1. ✅ **Track OCI container images** - Store metadata about container images
   including name, tag, digest, and hash
1. ✅ **Auto-update mechanism** - Periodically check for updates and update
   metadata files automatically
1. ✅ **Efficient checking** - Use skopeo to check remote digests without
   pulling entire images
1. ✅ **Store path management** - Query and build image store paths for cache
   publishing
1. ✅ **Pinning support** - Prevent automatic updates for specific images
1. **Future compatibility** - Design with NixNG container publishing in mind (to
   be implemented later)

## Architecture

### Component Overview

```
images/                          # Image metadata storage (similar to charts/)
├── DESIGN.md                   # This file
├── <namespace>/                # Namespace grouping (e.g., linuxserver)
│   └── <image-name>/           # Image name (e.g., radarr)
│       └── default.nix         # Image metadata
│
modules/flake-parts/
├── oci-images.nix              # Flake module exposing image metadata
│
pkgs/by-name/
└── oci-image-updater/          # Python utility for updating images
    ├── package.nix
    ├── README.md               # Comprehensive usage documentation
    └── oci_image_updater/
        ├── models/             # Data models (ImageMetadata, UpdateOperation)
        ├── utils/              # Utilities (ProcessUtils, NixUtils, GitUtils)
        ├── images/             # Image logic (discovery, updater, manager)
        ├── commands/           # CLI command handlers
        ├── __init__.py
        └── __main__.py         # CLI entry point
```

**Note**: Directory structure follows image namespaces (e.g.,
`linuxserver/radarr`) rather than semantic categories.

### Comparison to Helm Charts System

| Component                               | Helm Charts                           | OCI Images                            |                                       | ----------------                      |                                       |                                       |                                       |                                       |              |                                   |                |     |     |
| --------------------------------------- | ------------------------------------- | ------------------------------------- | ------------------------------------- | ------------------------------------- | ------------------------------------- | ------------------------------------- | ------------------------------------- | ------------------------------------- | ------------ | --------------------------------- | -------------- | --- | --- | --- | --- | ---------------- | --- | --- | --- |
| -------------------------------------   | ------------------------------------- |
| -------------------------------------   | ------------------------------------- |
| -------------------------------------   | ---------------------------------     |
| -------------------------------------   | ------------------------------------- |
| ------------                            | ---------------------------------     | ---                                   | ---                                   | ---                                   | ---                                   | ---                                   |
| ----------------                        | ---                                   | ---                                   | ---                                   |                                       | ------------------------------------- |
| -------------------------------------   |                                       | ------------------------------------- |
| -------------------------------------   |                                       |
| -------------------------------------   | ------------------------------------- |
| ---------------------                   | ------------------------------------- | --------------                        |
|                                         | ---------------------------------     | ------------                          | -----------------                     | ---                                   |
| ---                                     |                                       | ---                                   | ---                                   | ---                                   | ---                                   |                                       | ------------------------------------- |                                       |
| -------------------------------------   |                                       | ------------------------------------- |
|                                         | ------------------------------------- |                                       |                                       |
| -------------------------------------   | ---------------------                 |                                       |                                       |
| ---------------------                   | -------------------                   | ---                                   |                                       |                                       |
| ---------------------------------       | ------------                          | -----------------                     | ---                                   | ---                                   |
|                                         |                                       | ---                                   | ---                                   |                                       | ------------------------------------- |                                       |                                       |
| -------------------------------------   |                                       | ------------------------------------- |
|                                         |                                       | ------------------------------------- |                                       |                                       |                                       |
| -------------------------------------   | -------------------                   |                                       |                                       |                                       |
| ---------------------                   | ----------------                      | ------                                |                                       |                                       |                                       |
| ---------------------------------       | ------------                          | -----------------                     | ---                                   | ---                                   |
|                                         |                                       |                                       | ---                                   |                                       | ------------------------------------- |                                       |                                       |                                       |
| -------------------------------------   |                                       | ------------------------------------- |
|                                         |                                       |                                       | ------------------------------------- |                                       |                                       |                                       |                                       |
| -------------------------------------   | ------------------------------------- |
| ---------------------                   | ------                                | ---                                   | ---------------------------------     |                                       |                                       |
| ------------                            | -----------------                     | ---                                   | ---                                   |                                       |                                       |                                       |                                       |                                       |
| -------------------------------------   | ------------------------------------- |
| -------------------------------------   | ------------------------------------- |
|                                         |                                       |                                       |                                       |                                       | ------------------------------------- |                                       |                                       |                                       |              |
| -------------------------------------   |                                       | ---------------------                 | ---                                   |                                       |                                       |                                       |                                       |
| ------------                            | ------------                          | -----------------                     |                                       | -------------------                   |                                       |                                       |                                       |
| -----------------                       | ---------                             | ----------------                      | ---                                   |                                       | ---                                   | ---                                   | ---                                   |
| ---                                     |                                       |                                       |                                       |                                       | ---                                   |                                       | ------------------------------------- |                                       |              |                                   |                |     |
| -------------------------------------   |                                       | ------------------------------------- |
|                                         |                                       |                                       |                                       |                                       | ------------------------------------- |                                       |                                       |                                       |              |                                   |                |
| -------------------------------------   | ------                                | ---------------------                 |                                       |                                       |                                       |                                       |
| ------------                            | ------------                          | -----------------                     | -------------------                   |                                       |                                       |                                       |
|                                         | -----------------                     | ---------                             | ----------------                      | ---                                   | ---                                   | ---                                   | ---                                   |                                       |
| ---                                     |                                       | ------------------------------------- |                                       |
| -------------------------------------   |                                       |                                       |                                       |                                       |                                       |                                       |                                       |
| -------------------------------------   |                                       |                                       |                                       |                                       |                                       |                                       |
| -------------------------------------   |                                       | ------------------------------------- |
|                                         |                                       |                                       |                                       |                                       |                                       | ---                                   | ---------------------                 | ---                                   |              | ------------                      |                |     |
| -------------------                     |                                       |                                       |                                       | -----------------                     | ---------                             |                                       | ----------------                      |
| ---                                     | ---                                   | ---                                   | ---                                   |                                       |                                       |                                       |                                       | ------------------------------------- |              |                                   |                |
| -------------------------------------   |                                       |                                       |                                       |                                       |                                       |                                       |
| -------------------------------------   |                                       | ------------------------------------- |
|                                         |                                       |                                       |                                       |                                       |                                       |                                       | ---------------------------------     |                                       | ------------ |                                   |                |     |
| -------------------                     |                                       |                                       | ---                                   |                                       |                                       | -------------------                   |                                       | -----------------                     |
| ---------                               |                                       | ----------------                      |                                       | ---                                   |                                       |                                       | ---                                   | ---                                   |              |                                   |                |     |     |     |
| -------------------------------------   |                                       |                                       |                                       |                                       |                                       |                                       |                                       |                                       |
| -------------------------------------   |                                       | ------------------------------------- |
|                                         |                                       |                                       |                                       |                                       |                                       |                                       |                                       | ---------------------                 | ---          |                                   | -------------- |     |     |     |     |                  |     |     |
| -------------------------------------   | -----------------                     |                                       | ---------                             |                                       |                                       |
|                                         | ----------------                      | ------                                | ---                                   |                                       |                                       | ------------------------------------- |
|                                         |                                       | ---------------------                 |                                       |                                       | ------------------------------------- |                                       |                                       |                                       |
|                                         | ---------------------                 | --------------                        |                                       |                                       |                                       |                                       |
| -------------------------------------   |                                       |                                       |                                       |                                       |                                       | -----------------                     | ---------                             |
|                                         |                                       |                                       |                                       |                                       | ----------------                      | ------                                |                                       |                                       |              |                                   |                |     |     |     |
| -------------------------------------   |                                       |                                       | ---------------------                 |                                       |                                       |                                       |                                       |                                       |              |
| ---------------------                   | ---------------------                 |                                       |                                       |                                       |                                       |                                       |                                       |                                       |              |                                   |                |     |
| -------------------------------------   | -----------------                     | ---------                             |                                       |                                       |                                       |                                       |
| ----------------                        | ------                                | ---                                   |                                       | ------------------------------------- |                                       |
|                                         | ---------------------                 |                                       | ---------------------                 | ---------------------                 |                                       |
|                                         |                                       | ------------------------------------- | ---------                             | ----------------                      |                                       |                                       |
| ------                                  |                                       | ------------------------------------- |                                       |                                       |                                       |                                       |                                       |                                       |              |                                   |
| ---------------------------------       |                                       |                                       | ---------------------                 |                                       |                                       |                                       |                                       |                                       |              |                                   |                |
| -----------------                       | -----------------                     | ---                                   | ---                                   |                                       |                                       |                                       | ---------------------                 |
|                                         |                                       |                                       |                                       |                                       |                                       |                                       |                                       | ------------------------------------- |              |                                   |                |     |     |     |     |                  |     |     |     |
|                                         | ---------------------------------     | ---------                             | ----------------                      |                                       |                                       |                                       |                                       |                                       |
|                                         |                                       | ----------------                      |                                       | ------------------------------------- |                                       |                                       |                                       |                                       |              |                                   |                |
|                                         |                                       | ---------------------------------     |                                       | ---------------------                 |                                       |
| ----------------                        |                                       |                                       |                                       |                                       | ----------------                      | ------------                          |                                       |                                       |              |
| ---------------------                   |                                       |                                       |                                       |                                       |                                       |                                       |                                       |                                       |              | --------------------------------- |                |
| ---------------------                   |                                       |                                       |                                       |                                       | ----------------                      |                                       |                                       |                                       |              |                                   |                |     |     |     | --- |                  |
| ------------                            |                                       |                                       |                                       |                                       |                                       |                                       |                                       | -----------------                     |              |                                   |                |     |     |     |     |                  |     |     |
| ---------------------------------       |                                       |                                       |                                       |                                       | ---------------------                 |                                       |                                       |
| ------------                            |                                       |                                       |                                       | Metadata Storage                      | `charts/`                             |                                       |                                       | `images/`                             |              | Flake                             |                |
| Module                                  |                                       |                                       |                                       |                                       |                                       |                                       |                                       |                                       |              | `helm-charts.nix`                 |                |     |     |     |     | `oci-images.nix` |     |     |
| Updater Tool                            | `nixhelm#helmupdater`                 |                                       |                                       |                                       |                                       |                                       |                                       |                                       |              |                                   |                |     |     |     |     |
| `oci-image-updater`                     |                                       | Discovery                             | haumea auto-load                      |                                       |                                       | haumea                                |                                       |                                       |              |                                   |                |
| auto-load                               |                                       |                                       |                                       |                                       | Flake Output                          | `chartsMetadata`,                     |                                       |                                       |              |                                   |                |     |     |     |     |
| `chartsDerivations`                     |                                       |                                       | `imagesMetadata`,                     |                                       |                                       |                                       | `imagesDerivations`                   |                                       |              |                                   |
| Update Command                          |                                       |                                       |                                       |                                       | `helmupdater update-all --commit`     |                                       |                                       |                                       |              |                                   |                |     |     |     |
| `oci-image-updater update-all --commit` |

## Metadata Schema

### File Structure

Each image is defined in `images/<namespace>/<image-name>/default.nix`:

```nix
{
  imageName = "linuxserver/radarr";
  imageTag = "nightly";
  imageDigest = "sha256:eddff691c5894288fc97bcb70ff9c3fb0bb9664cec8c2760f212edcde99f2fed";
  imageHash = "sha256-QUjZa92kZkWWNZY5KqG4Z4UgWVA7GifaF2pE/DdzQe4=";
  arch = "amd64";
  os = "linux";
  pinned = false;  # Optional: prevent automatic updates
}
```

### Field Descriptions

- **imageName**: Full image name including registry path (e.g.,
  `linuxserver/radarr`, `docker.io/library/nginx`)
- **imageTag**: The tag to track (e.g., `nightly`, `latest`, `v1.2.3`)
- **imageDigest**: SHA256 digest of the manifest (sha256:...)
- **imageHash**: Nix SRI hash of the image tarball (sha256-...)
- **arch**: CPU architecture (amd64, arm64, etc.)
- **os**: Operating system (linux, darwin, etc.)
- **pinned**: (Optional) Set to `true` to prevent automatic updates. Defaults to
  `false` if omitted.

### Design Decisions

1. **Tag Tracking**: Users specify the exact tag to track (e.g., `nightly`,
   `latest`, `v1.2.3`). The updater checks if the digest for that tag has
   changed.

1. **Platform Specification**: Both `arch` and `os` are required to ensure we
   fetch the correct image variant for multi-platform images.

1. **Registry Handling**: Registry is embedded in `imageName` following Docker
   convention (docker.io is implicit for library images).

1. **Minimal Schema**: We keep the schema minimal for now. Future NixNG
   integration can extend this without breaking changes.

## Implementation Status

### Phase 1: Foundation ✅ **COMPLETE**

1. ✅ **Directory Structure**
   - Created `images/` directory at repo root
   - Sample images: `linuxserver/radarr`, `linuxserver/lidarr`,
     `linuxserver/sonarr`

1. ✅ **Flake Integration**
   - Implemented `modules/flake-parts/oci-images.nix`
   - Uses haumea for auto-discovery (same pattern as helm-charts)
   - Exposes `imagesMetadata` for tooling consumption
   - Exposes `imagesDerivations` for building images
   - Tested with: `nix eval .#imagesMetadata --json`

1. ✅ **Python Updater Tool**
   - Implemented in `pkgs/by-name/oci-image-updater/`
   - Modular architecture inspired by k8s-update-manifests
   - Commands: init, update-all, check-all, list-path, list-paths, build-image,
     build-images
   - Uses skopeo for efficient digest checking
   - Uses nix-prefetch-docker for hash calculation
   - Fixed Nix attribute set parsing for prefetch output
   - Refactored into command modules for maintainability

### Phase 2: Automation (Future)

1. **GitHub Actions**
   - Nightly workflow to run `oci-image-updater update-all --commit`
   - Auto-create PRs with updates

1. **Notification**
   - Optional notifications on updates

### Phase 3: NixNG Integration (Future)

1. **Container Resources**
   - Define new flake resource type for NixNG containers
   - Leverage image metadata for container definitions
   - Publishing workflow for built containers

## Updater Tool Design

### CLI Interface

```bash
# Initialize a new image
oci-image-updater init \
  --image-name linuxserver/radarr \
  --image-tag nightly \
  --arch amd64 \
  --os linux \
  [--pinned]  # Optional: prevent automatic updates

# Update all images (skips pinned images)
oci-image-updater update-all [--commit] [--dry-run] [--verbose]

# Check for updates without applying (skips pinned images)
oci-image-updater check-all

# Get Nix store path for a specific image (without building)
oci-image-updater list-path linuxserver/radarr

# Get store paths for all images (JSON output)
oci-image-updater list-paths [--system x86_64-linux]

# Build a specific image to populate local store
oci-image-updater build-image linuxserver/radarr

# Build all images to populate local store
oci-image-updater build-images
```

### Command Architecture

The CLI is organized into focused command modules:

- **`commands/init.py`**: Initialize new image metadata files
- **`commands/update.py`**: Update and check commands
- **`commands/paths.py`**: Store path listing (uses `nix eval .#image.outPath`)
- **`commands/build.py`**: Build images to populate store
- **`commands/common.py`**: Shared utilities (logging, validation)

### Update Algorithm

1. **Discovery**: Query flake for `imagesMetadata`
1. **Check**: For each image, use skopeo to get current digest:
   ```bash
   skopeo inspect --format '{{.Digest}}' \
     docker://linuxserver/radarr:nightly \
     --override-arch amd64 --override-os linux
   ```
1. **Compare**: If remote digest differs from stored digest:
   - Use `nix-prefetch-docker` to fetch and hash the image
   - Update `default.nix` with new digest and hash
   - Optionally commit changes

### Dependencies

- **skopeo**: Efficient remote image inspection
- **nix-prefetch-docker**: Fetch and hash images for Nix
- **nix**: Query flake metadata
- **git**: Commit changes
- **python3**: Runtime and PyYAML for any YAML needs

## Flake Integration

### Output Schema

The flake exposes:

```nix
{
  imagesMetadata = {
    linuxserver = {
      radarr = {
        imageName = "linuxserver/radarr";
        imageTag = "nightly";
        imageDigest = "sha256:...";
        imageHash = "sha256-...";
        arch = "amd64";
        os = "linux";
        pinned = false;  # Optional, defaults to false
      };
    };
  };

  # Derivations for building/fetching images
  imagesDerivations = {
    x86_64-linux = {
      linuxserver = {
        radarr = <derivation>;
      };
    };
  };
}
```

### Query Examples

```bash
# Get all images metadata
nix eval .#imagesMetadata --json

# Get specific image
nix eval .#imagesMetadata.linuxserver.radarr --json

# Get image store path without building
nix eval --raw .#imagesDerivations.x86_64-linux.linuxserver.radarr.outPath

# Build an image
nix build .#imagesDerivations.x86_64-linux.linuxserver.radarr
```

## Integration with Existing Systems

### Similarities to Helm Charts

- Auto-discovery via haumea
- Nightly updates via GitHub Actions
- Structured metadata files
- Flake output exposure

### Differences from Helm Charts

- No chart repository concept (just registry + tag)
- Platform-specific (arch/os required)
- Digest-based change detection (cheaper than hash)
- Two-phase update (skopeo check, then prefetch if changed)

## Future Considerations

### NixNG Container Publishing

When we implement NixNG container resources, we'll:

1. Define container resources that reference images from `imagesMetadata`
1. Build containers using NixNG
1. Publish to container registry
1. Update running containers via deployment tools

The current image metadata schema is forward-compatible with this workflow.

### Alternative Update Strategies

Future enhancements could include:

- Semver constraints (track `v1.x.x` pattern)
- Update policies (auto-update vs. manual approval)
- Rollback mechanisms
- Multi-architecture builds (track multiple arch/os combos per image)

## Testing Strategy

### Manual Testing ✅ **COMPLETE**

1. ✅ Created sample image metadata (radarr, lidarr, sonarr)
1. ✅ Queried via flake outputs (`nix eval .#imagesMetadata --json`)
1. ✅ Tested init command to create new images
1. ✅ Tested update-all to detect and apply updates
1. ✅ Tested check-all for update detection
1. ✅ Tested pinned functionality (images correctly skipped)
1. ✅ Tested list-path and list-paths commands
1. ✅ Tested build-image and build-images commands
1. ✅ Verified JSON output from list-paths

### Integration Testing (Future)

1. Mock skopeo responses
1. Test update detection logic
1. Test file generation
1. Test git operations

### CI Testing (Future)

1. Verify flake outputs are valid
1. Run updater in dry-run mode
1. Validate generated Nix files

## Migration Path

### For New Images

1. Run `oci-image-updater init` with appropriate flags
1. Commit the generated `default.nix`
1. Updates will be automated thereafter

### For Existing Container Definitions

1. Identify hardcoded container references
1. Extract to `images/` metadata files
1. Update references to use flake outputs
1. Enable auto-updates

## Implementation Highlights

### Key Features Implemented

1. **Pinning Support**: Images can be marked as `pinned = true` to prevent
   automatic updates
1. **Efficient Checking**: Uses skopeo to check digests without downloading
   images
1. **Two-Phase Updates**: Check with skopeo first, only download if changed
1. **Store Path Queries**: Get Nix store paths without building (uses
   `nix eval .#image.outPath`)
1. **JSON Output**: Machine-readable output for list-paths command
1. **Modular Architecture**: Organized into models, utils, images, and command
   modules
1. **Type Safety**: Full type hints throughout Python codebase
1. **Git Integration**: Optional automatic commits with summary messages

### Technical Decisions

1. **Parser Fix**: Fixed nix-prefetch-docker output parsing to extract Nix
   attribute set correctly
1. **Command Refactoring**: Moved from monolithic `__main__.py` to command
   modules for maintainability
1. **Default Values**: Pinned field is optional (defaults to false) to keep
   files clean
1. **Namespace Structure**: Follows Docker image naming (linuxserver/radarr)
   rather than semantic categories

### Current Limitations

1. Single architecture per image (no multi-arch tracking yet)
1. No semver constraint support (tracks exact tags only)
1. No automated GitHub Actions workflow yet
1. No rollback mechanism

## References

- **Helm chart updater**: Pattern inspiration for flake integration
- **k8s-update-manifests**: Architecture inspiration for modular design
- **nix-prefetch-docker**: Fetches and hashes images
- **skopeo**: Efficient remote image inspection
- **haumea**: Auto-discovery library used by flake-parts
- **dockerTools.pullImage**: Nix function for creating image derivations
