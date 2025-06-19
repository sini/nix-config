<h1 align="center"> <img src="./.github/assets/flake.webp" width="250px"/></h1>
<h2 align="center">Nexus.nix -- my personal multi-host flake configuration</h2>

<h1 align="center">
<a href='#'><img src="https://raw.githubusercontent.com/catppuccin/catppuccin/main/assets/palette/macchiato.png" width="600px"/></a>
  <br>
  <br>
  <div>
    <a href="https://github.com/sini/nix-config/issues">
        <img src="https://img.shields.io/github/issues/sini/nix-config?color=fab387&labelColor=303446&style=for-the-badge">
    </a>
    <a href="https://github.com/sini/nix-config/stargazers">
        <img src="https://img.shields.io/github/stars/sini/nix-config?color=ca9ee6&labelColor=303446&style=for-the-badge">
    </a>
    <a href="https://github.com/sini/nix-config">
        <img src="https://img.shields.io/github/repo-size/sini/nix-config?color=ea999c&labelColor=303446&style=for-the-badge">
    </a>
    <a href="https://github.com/sini/nix-config/blob/main/.github/LICENCE">
        <img src="https://img.shields.io/static/v1.svg?style=for-the-badge&label=License&message=GPL-3&logoColor=ca9ee6&colorA=313244&colorB=cba6f7"/>
    </a>
    <br>
    </div>
        <img href="https://builtwithnix.org" src="https://builtwithnix.org/badge.svg"/>
   </h1>
   <br>

# Installing

Migrate to this pattern https://github.com/mightyiam/dendritic

# Requirements

Yubikey 5

# Resources

I've stolen shamelessly from:

- [NotAShelf/nyx](https://github.com/NotAShelf/nyx)

- https://github.com/EmergentMind/nix-config/tree/dev

- https://github.com/oddlama/nix-config/tree/main

- https://git.kun.is/pim/nixos-configs/src/branch/master

-

- [JakeHamilton/config](https://github.com/jakehamilton/config) - where it
  started

- [Misterio77](https://github.com/Misterio77/nix-config/)

- [JManch](https://github.com/JManch/nixos)

- [hmajid2301/nixicle](https://github.com/hmajid2301/nixicle/tree/main)

- [IogaMaster/dotfiles](https://github.com/IogaMaster/dotfiles/) - another good
  snowfall-lib config

- [khaneliman/khanelinix](https://github.com/khaneliman/khanelinix) - another
  really good config

- [FelixKrats/dotfiles](https://github.com/FelixKratz/dotfiles) \*Sketchybar
  design and implementation

- [Fufexan/dotfiles](https://github.com/fufexan/dotfiles)

- [NotAShelf/nyx](https://github.com/NotAShelf/nyx)

- [clo4/nix-dotfiles](https://github.com/clo4/nix-dotfiles)

- https://www.youtube.com/watch?v=uP9jDrRvAwM https://github.com/notashelf/nvf

- Mac Configs:

  - https://github.com/rounakdatta/dotfiles
  - https://github.com/dustinlyons/nixos-config
  - https://github.com/srid/nixos-unified
  - https://github.com/tbreslein/.dotfiles
  - https://github.com/khaneliman/khanelinix

- https://github.com/AlexNabokikh/nix-config

- https://github.com/Gerg-L/spicetify-nix

- https://github.com/catppuccin/egui

- https://github.com/justinlime/dotfiles

- https://github.com/omerxx/dotfiles/tree/master

- https://code.m3tam3re.com/m3tam3re/nixcfg/src/branch/video18

- https://github.com/arvigeus/nixos-config/tree/master

- https://mt-caret.github.io/blog/posts/2020-06-29-optin-state.html

- https://unmovedcentre.com/posts/secrets-management/

- https://www.youtube.com/watch?v=2yplBzPCghA

- https://github.com/badele/nix-homelab/tree/main

- https://github.com/VTimofeenko/monorepo-machine-config/tree/master

- https://github.com/mightyiam/infra/tree/main

- https://pim.kun.is/nix-jekyll-derivation/

- https://github.com/oddlama/nix-config/tree/main

- https://github.com/niki-on-github/nixos-k3s/tree/main#

- https://github.com/wimpysworld/nix-config/tree/main#

- https://github.com/fufexan/dotfiles?tab=readme-ov-file#

- https://github.com/JManch/nixos/tree/main

- https://github.com/baitinq/nixos-config?tab=readme-ov-file

- https://github.com/akirak/homelab

- https://github.com/eh8/chenglab/tree/main

- https://git.eisfunke.com/config/nixos/-/tree/main

## Project Overview and Key Technologies

This repository contains a comprehensive NixOS and Home Manager configuration managed as a Nix Flake. It's designed to configure multiple hosts (NixOS and macOS) in a declarative and reproducible way.

### File Hierarchy Highlights

The repository is structured to promote modularity and clarity:

- **`/flake.nix`**: The main entry point for the Nix flake, defining inputs and outputs.
- **`/flake-parts/`**: Contains modular components of the flake, making the configuration easier to manage. Notably:
  - `agenix-rekey.nix`: Configures `agenix` for secret management (see below).
  - `colmena.nix`: Configures `Colmena` for deploying configurations to multiple hosts (see below).
- **`/hm/`**: Holds Home Manager configurations, allowing for user-specific package management and dotfile configuration across different hosts.
- **`/lib/`**: A collection of custom helper functions and Nix libraries used throughout the configuration.
- **`/modules/`**: Defines NixOS and Home Manager modules. These are broken down into:
  - `common/`: Settings applicable to all systems.
  - `darwin/`: Configurations specific to macOS hosts.
  - `nixos/`: Configurations specific to NixOS hosts.
  - `home/`: Modules specifically for Home Manager.
- **`/overlays/`**: Provides custom Nix package overlays, allowing for modifications or additions to the standard Nixpkgs set.
- **`/secrets/`**: Manages encrypted secrets using `agenix`. This directory includes public keys, instructions for key generation (often with YubiKeys), and the encrypted secret files themselves, organized per host.
- **`/systems/`**: This is where individual host configurations are defined. Each host (e.g., a server or a laptop) has its own subdirectory, typically organized by architecture (`x86_64-linux`, `aarch64-darwin`) and then by hostname. Each host's configuration specifies its modules, system settings, and potentially hardware-specific details.
- **`/topology/default.nix`**: Defines the network layout and relationships between the managed hosts, primarily for use by Colmena.

### Core Technologies

Several key tools are at the heart of this setup:

- **Agenix**:

  - **Role**: Securely manages secrets (API keys, passwords, private keys, etc.) within the Nix configuration.
  - **Implementation**: Secrets are encrypted using `age` (often with keys stored on YubiKeys for enhanced security) and stored directly in the repository. The `agenix-rekey` tool is configured in `flake-parts/agenix-rekey.nix` to facilitate the rotation and management of these encryption keys.
  - **Usage**: During a Nix build or deployment, `agenix` decrypts the necessary secrets for the target host, making them available to services or user configurations. The actual encrypted files are typically found in `secrets/generated/` or `secrets/rekeyed/`.

- **Colmena**:

  - **Role**: Deploys NixOS configurations to multiple hosts simultaneously. It allows you to manage a fleet of machines from a single flake.
  - **Implementation**: Configured in `flake-parts/colmena.nix`, Colmena takes the host definitions from the `/systems/` directory and applies their configurations remotely. It uses SSH to connect to the target machines.
  - **Usage**: Commands like `colmena apply` or `colmena apply-local` are used to push out new configurations or updates to the defined nodes. The `/topology/default.nix` file can provide Colmena with information about the network structure.

- **NixOS Anywhere & Disko**:

  - **Role**: While Colmena _deploys_ to existing NixOS systems, `nixos-anywhere` is a tool often used for the _initial installation_ of NixOS on bare-metal machines or VMs, especially remotely. `Disko` is a tool for declarative disk partitioning within NixOS.
  - **Presence**: There isn't a direct, explicit configuration file for `nixos-anywhere` in the flake's core structure, suggesting it might be used more as an ad-hoc command-line tool for provisioning new systems.
  - **Connection**: The presence of `disko.nix` files (e.g., `systems/x86_64-linux/spike/disko.nix`) indicates that declarative disk partitioning is used for some hosts. `nixos-anywhere` can leverage `disko` configurations to prepare disks during the installation process. This setup allows for a fully reproducible installation from scratch.

This overview should help in navigating the repository and understanding its operational principles.
