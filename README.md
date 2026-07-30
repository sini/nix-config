<div align="center">
  <img src="https://raw.githubusercontent.com/sini/nix-config/main/modules/docs/logo/logo.png" width="120px" />
</div>

<br />

<br>

# sini/nix-config

<br>
<div align="center">
    <a href="https://github.com/sini/nix-config/stargazers">
        <img src="https://img.shields.io/github/stars/sini/nix-config?color=c14d26&labelColor=0b0b0b&style=for-the-badge&logo=starship&logoColor=c14d26">
    </a>
    <a href="https://github.com/sini/nix-config">
        <img src="https://img.shields.io/github/repo-size/sini/nix-config?color=c14d26&labelColor=0b0b0b&style=for-the-badge&logo=github&logoColor=c14d26">
    </a>
    <a href="https://nixos.org">
        <img src="https://img.shields.io/badge/NixOS-unstable-blue.svg?style=for-the-badge&labelColor=0b0b0b&logo=NixOS&logoColor=c14d26&color=c14d26">
    </a>
    <a href="https://github.com/sini/nix-config/blob/main/LICENSE">
        <img src="https://img.shields.io/static/v1.svg?style=for-the-badge&label=License&message=MIT&colorA=0b0b0b&colorB=c14d26&logo=unlicense&logoColor=c14d26"/>
    </a>
</div>
<br>

sini's [NixOS](https://nix.dev) homelab and workstation configuration repository.

> [!NOTE]
> If you have any questions or suggestions, feel free to contact me via e-mail `jason <at> json64 <dot> dev`.


## Hosts

| Name                                  | Description                                                                                             |    Type     |      Arch      |
| :------------------------------------ | :------------------------------------------------------------------------------------------------------ | :---------: | :------------: |
| [uplink](modules/den/hosts/uplink.nix)       | Ryzen 5950X (16/32) - 128GB - 10gbe - Intel Arc A310 - AV1 Transcoding / Router / k8s control           |   Server    |  x86_64-linux  |
| [axon-01](modules/den/hosts/axon-01.nix)     | MINISFORUM Venus UM790 Pro - Ryzen 9 7940HS (8/16) - 64GB - 2.5gbe - Radeon 780M - k8s node             |   Server    |  x86_64-linux  |
| [axon-02](modules/den/hosts/axon-02.nix)     | MINISFORUM Venus UM790 Pro - Ryzen 9 7940HS (8/16) - 64GB - 2.5gbe - Radeon 780M - k8s node             |   Server    |  x86_64-linux  |
| [axon-03](modules/den/hosts/axon-03.nix)     | MINISFORUM Venus UM790 Pro - Ryzen 9 7940HS (8/16) - 64GB - 2.5gbe - Radeon 780M - k8s node             |   Server    |  x86_64-linux  |
| [bitstream](modules/den/hosts/bitstream.nix) | GMKtec M6 - Ryzen 5 6600H (8/16) - 64GB - 2.5gbe - Radeon 660M - k8s node                               |   Server    |  x86_64-linux  |
| [cortex](modules/den/hosts/cortex.nix)       | Ryzen 9950X3D (16/32) - 128GB - 10gbe - 7900XTX + 3090TI - Hybrid ML Server/Workstation/VFIO Gaming Rig | Workstation |  x86_64-linux  |
| [blade](modules/den/hosts/blade.nix)         | Razer Blade 16 (2023) - NixOS - 32GB ram - RTX 4090 (mobile)                                            |   Laptop    |  x86_64-linux  |
| [patch](modules/den/hosts/patch.nix)         | M1 Macbook Air - 16gb / 1tb - macOS Sequoia 15.2                                                        |   Laptop    | aarch64-darwin |


## Architecture

This configuration uses [den](https://github.com/sini/den) for declarative multi-entity system management, with [gen-schema](https://github.com/denful/gen-schema) for typed entity registries and [scope-engine](https://github.com/denful/scope-engine) for hierarchical settings resolution.

### Entity Model

Entity types are defined via gen-schema with strict validation, cross-registry refs, and identity hashing:

| Entity | Purpose |
| :--- | :--- |
| `environment` | Domain, networks, certs, delegation, service domains |
| `group` | Membership labels, transitive resolution, ACL gating |
| `host` | Channel, networking, settings, system-owner, facts |
| `user` | Identity (SSH, GPG), system config (uid, groups) |
| `cluster` | K8s cluster: role-based host discovery, networks |

### Policy Chain

Entities are resolved through a scope tree driven by policies:

```
fleet
 +-> environment       (fan out den.environments)
     +-> host           (match host.environment)
     |   +-> user       (ACL-gated via group intersection)
     +-> cluster        (match cluster.environment)
         +-> host       (role-based membership)
```

User assignment is ACL-driven via `fleet.user-access` group mappings against `den.users.registry`, not den's built-in host-to-users policy.

### Aspects

Configuration is organized into 216 aspects across 13 categories:

| Category | Examples |
| :--- | :--- |
| `core/` | nix, nixpkgs, boot, i18n, systemd, shell, security, impermanence |
| `network/` | networking (systemd-networkd), manager, hosts, wireless, avahi |
| `disk/` | ZFS (root + disko layout), impermanence, btrfs, xfs |
| `hardware/` | cpu-amd/intel, gpu-amd/nvidia, laptop, razer, performance |
| `desktop/` | hyprland, kde, gnome, stylix, fonts |
| `apps/` | browsers, dev tools, gaming, media, messaging, shell utilities |
| `services/` | haproxy, nginx, k3s, vault, prometheus, kanidm, jellyfin |
| `roles/` | workstation, server, dev, gaming, media, nix-builder |
| `secrets/` | agenix + agenix-rekey integration, custom generators |
| `kubernetes/` | argocd, cilium, cert-manager, storage, gateway-api |
| `virtualization/` | libvirt, podman, microvm |
| `system/` | ananicy |
| `devshell/` | colmena CLI |

Aspects emit into class keys (`nixos`, `darwin`, `homeManager`) and quirks (`firewall`, `persist`, `secrets`, etc.). Roles are composite aspects that bundle features via `includes`.

### Quirks (Pipe Data)

Cross-cutting concerns collected from aspects and aggregated at host/user scope:

`firewall` `persist` `cache` `persistHome` `cacheHome` `secrets` `resolved-users` `service-domains` `prometheus-targets` `k8s-manifests` `nix-builders` `host-addrs` `bgp-peers` `vault-peers`

### Batteries

| Battery | Purpose |
| :--- | :--- |
| `agenix` | Secret management: agenix-rekey per host/user, identity keys, HM integration |
| `colmena` | Fleet deployment via colmena hive with per-channel nixpkgs |
| `nixidy` | K8s manifest collection per cluster via policy.instantiate |

### Custom Classes

| Class | Routes Into | Guard |
| :--- | :--- | :--- |
| `homeLinux` | `homeManager` | `host.system` ends with `-linux` |
| `homeDarwin` | `homeManager` | `host.system` ends with `-darwin` |
| `homeAarch64` | `homeManager` | `host.system` starts with `aarch64-` |
| `devshell` | `flake-parts` | (always) |

### Settings Resolution

Feature settings use scope-engine for demand-driven resolution with automatic precedence: aspect defaults -> environment -> host -> user. Override provenance tracking shows where each setting came from.

### Directory Layout

```
modules/den/
+-- schema/          Entity type definitions (host, environment, user, group, cluster)
+-- environments/    Environment instances (prod, dev)
+-- groups/          Group definitions (admins, system-access, ...)
+-- users/           User registry + per-user aspects
+-- hosts/           Host definitions + per-host aspects
+-- clusters/        Cluster definitions (axon)
+-- aspects/         216 aspect modules across 13 categories
+-- policies/        Scope resolution policies (fleet, hosts, users, pipes)
+-- quirks/          Pipe data type declarations
+-- classes/         Custom class definitions + route policies
+-- batteries/       Agenix, colmena, nixidy integration
+-- scope-engine/    Settings + ACL resolution graphs
+-- defaults.nix     Default includes, quirk collectors, user-aspect auto-include
```


## Automatic import

Nix files (they're all flake-parts modules) are automatically imported.
Nix files prefixed with an underscore are ignored.
No literal path imports are used.
This means files can be moved around and nested in directories freely.

> [!NOTE]
> This pattern has been the inspiration of [an auto-imports library, import-tree](https://github.com/vic/import-tree).


## Generated files

The following files in this repository are generated and checked
using [the ENHANCED _files_ flake-parts module](https://github.com/sini/files):

- `.gitignore`
- `LICENSE`
- `README.md`
- `.sops.yaml`
- `.secrets/secrets-manifest.md`


## Trying to disallow warnings

This at the top level of the `flake.nix` file:

```nix
nixConfig.abort-on-warn = true;
```

> [!NOTE]
> It does not currently catch all warnings Nix can produce, but perhaps only evaluation warnings.


## Notable Links

### Other dendritic users:

- [GaetanLepage/nix-config](https://github.com/GaetanLepage/nix-config/)
- [vic/vix](https://github.com/vic/vix)
- [drupol/infra](https://github.com/drupol/infra/tree/master)

### Other inspirational nix configs:

- [oddlama/nix-config](https://github.com/oddlama/nix-config/)
- [JManch/nixos](https://github.com/JManch/nixos)
- [akirak/homelab](https://github.com/akirak/nix-config/)
- [pim/nix-config](https://git.kun.is/pim/nixos-configs) & [pim's kubernetes configs](https://git.kun.is/home/kubernetes-deployments)

### Notable References:

- [colmena](https://github.com/zhaofengli/colmena)
- [agenix](https://github.com/ryantm/agenix) & [agenix-rekey](https://github.com/oddlama/agenix-rekey)
- [flake-parts](https://flake.parts/)
