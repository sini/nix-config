# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a NixOS configuration repository managing a homelab with Kubernetes nodes, workstations, and laptops. It uses a dendritic configuration pattern with automatic module imports and manages multiple hosts through Colmena and deploy-rs.

## Key Architecture

### Hosts Configuration

Hosts are defined in `modules/hosts/` with their own configuration modules. Each host has:

- System architecture (x86_64-linux, aarch64-darwin)
- IP addresses configured in `flake.hosts.<hostname>.ipv4`
- Roles (server, workstation, laptop)
- Hardware configuration via Facter JSON files
- Deployment settings for remote management

### Module System

- **Automatic imports**: All `.nix` files are automatically imported as flake-parts modules (files prefixed with `_` are ignored)
- **Core modules**: `modules/core/` - System essentials (SSH, boot, sudo, etc.)
- **App modules**: `modules/apps/` - Applications organized by category (desktop, dev, gaming, media, productivity)
- **Hardware modules**: `modules/hardware/` - Hardware-specific configurations
- **Roles**: `modules/roles/` - High-level role configurations (kubernetes, media, laptop)
- **Features**: `modules/features/` - Optional features and capabilities
- **Services**: `modules/services/` - System level services for server hosts

### Secrets Management

Uses agenix and agenix-rekey for secret management. Secrets are stored encrypted in `.secrets/` directory.

## Common Development Commands

### Building and Testing

```bash
# Build a specific host configuration (without deploying)
build <hostname>  # e.g., build cortex

# Run flake checks
nix flake check

# Format all files
treefmt

# Update flake inputs with GitHub authentication
flake-update
```

### Deployment Commands

```bash
# Deploy to all hosts
colmena apply

# Deploy to a specific host
colmena apply --on <hostname>

# Deploy to hosts with a specific role
colmena apply --on @server

# Apply changes to current host
colmena apply-local --sudo

# Alternative deployment with deploy-rs
deploy .#<hostname>
```

### Kubernetes Cluster Management

```bash
# Reset the entire k3s cluster (axon nodes)
reset-axon

# Access k3s cluster
export KUBECONFIG=$HOME/.config/kube/config
kubectl get nodes
```

### Development Workflow

1. Enter development shell: `direnv allow` (automatic with direnv) or `nix develop`
1. Make changes to configuration files
1. Test locally: `build <hostname>` to verify build
1. Deploy: `colmena apply --on <hostname>`
1. Commit changes with pre-commit hooks automatically running

## Important Patterns

### Adding a New Host

1. Create directory `modules/hosts/<hostname>/`
1. Add `default.nix` with host configuration
1. Configure in flake with `flake.hosts.<hostname>` options
1. Generate hardware config with nixos-facter if needed

### Module Development

- Follow existing code conventions in neighboring files
- Use deterministic UIDs/GIDs defined in `modules/core/deterministic-uids/users.nix`
- Prefer editing existing modules over creating new ones
- Check imports and dependencies before adding libraries

### Nixpkgs Versions

- Stable hosts use `nixpkgs` (25.05)
- Unstable hosts use `nixpkgs-unstable`
- Set via `flake.hosts.<hostname>.unstable` option

## Repository Structure

```
.
├── flake.nix           # Main flake configuration
├── modules/            # All NixOS/nix-darwin modules
│   ├── hosts/         # Per-host configurations
│   ├── core/          # Core system modules
│   ├── apps/          # Application modules
│   ├── hardware/      # Hardware configurations
│   ├── roles/         # High-level roles
│   ├── services/      # System service modules
│   └── flake-parts/   # Flake infrastructure
├── pkgs/              # Custom packages
└── .secrets/          # Encrypted secrets (agenix)
```
