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

<a href="https://github.com/sini/nix-config/actions/workflows/check.yml?query=branch%3Amain">
<img
  alt="CI status"
  src="https://img.shields.io/github/actions/workflow/status/sini/nix-config/check.yml?style=for-the-badge&branch=main&label=Check"
>
</a>

## Hosts

| Name                                  | Description                                                                                             |    Type     |      Arch      |
| :------------------------------------ | :------------------------------------------------------------------------------------------------------ | :---------: | :------------: |
| [uplink](modules/hosts/uplink/)       | Ryzen 5950X (16/32) - 128GB - 10gbe - Intel Arc A310 - AV1 Transcoding / Router / k8s control           |   Server    |  x86_64-linux  |
| [axon-01](modules/hosts/axon-01/)     | MINISFORUM Venus UM790 Pro - Ryzen 9 7940HS (8/16) - 64GB - 2.5gbe - Radeon 780M - k8s node             |   Server    |  x86_64-linux  |
| [axon-02](modules/hosts/axon-02/)     | MINISFORUM Venus UM790 Pro - Ryzen 9 7940HS (8/16) - 64GB - 2.5gbe - Radeon 780M - k8s node             |   Server    |  x86_64-linux  |
| [axon-03](modules/hosts/axon-03/)     | MINISFORUM Venus UM790 Pro - Ryzen 9 7940HS (8/16) - 64GB - 2.5gbe - Radeon 780M - k8s node             |   Server    |  x86_64-linux  |
| [bitstream](modules/hosts/bitstream/) | GMKtec M6 - Ryzen 5 6600H (8/16) - 64GB - 2.5gbe - Radeon 660M - k8s node                               |   Server    |  x86_64-linux  |
| [cortex](modules/hosts/cortex/)       | Ryzen 9950X3D (16/32) - 128GB - 10gbe - 7900XTX + 3090TI - Hybrid ML Server/Workstation/VFIO Gaming Rig | Workstation |  x86_64-linux  |
| [spike](modules/hosts/spike/)         | Razer Blade 16 (2023) - NixOS - 32GB ram - RTX 4090 (mobile)                                            |   Laptop    |  x86_64-linux  |
| [patch](modules/hosts/patch/)         | M1 Macbook Air - 16gb / 1tb - macOS Sequoia 15.2                                                        |   Laptop    | aarch64-darwin |
| [vault](modules/hosts/vault/)         | 1tb NVME + 80tb NFS - 2x1gbe + 2.5gbe                                                                   |     NAS     |  x86_64-linux  |

## Host Options

This repository defines a set of hosts in the `flake.hosts` attribute set.
Each host is defined as a submodule with its own configuration options.
The host configurations can be used to deploy NixOS configurations to remote
machines using Colmena or for local development. These options are defined for
every host and include:

- `system`: The system architecture of the host (e.g., `x86_64-linux`).
- `unstable`: Whether to use unstable packages for the host.
- `ipv4`: The static IP addresses of this host in it's home vlan.
- `ipv6`: The static IPv6 addresses of this host.
- `roles`: A list of roles for the host, which can also be used to target deployment.
- `features`: A list of features to enable for the host.
- `exclude-features`: A list of features to exclude (prevents the feature and its requires from being added).
- `public_key`: The path or value of the public SSH key for the host used for encryption.
- `facts`: The path to the Facter JSON file for the host, which is used to provide
  additional information about the host and for automated hardware configuration.
- `extra_modules`: A list of additional modules to include for the host.
- `tags`: An attribute set of string key-value pairs to annotate hosts with metadata.
  For example: `{ "kubernetes-cluster" = "prod"; "kubernetes-internal-ip" = "10.0.1.100"; }`
  Special tags:
  - `kubernetes-cluster`: Groups hosts into Kubernetes clusters
  - `kubernetes-internal-ip`: Override IP for Kubernetes internal communication (defaults to host ipv4)
  - `bgp-asn`: BGP AS number for this host (used by bgp-hub and thunderbolt-mesh modules)
  - `thunderbolt-loopback-ipv4`: Loopback IPv4 address for thunderbolt mesh BGP peering (e.g., "172.16.255.1/32")
  - `thunderbolt-loopback-ipv6`: Loopback IPv6 address for thunderbolt mesh BGP peering (e.g., "fdb4:5edb:1b00::1/128")
  - `thunderbolt-interface-1`: IPv4 address for first thunderbolt interface (e.g., "169.254.12.0/31")
  - `thunderbolt-interface-2`: IPv4 address for second thunderbolt interface (e.g., "169.254.31.1/31")
- `exporters`: An attribute set defining Prometheus exporters exposed by this host.
  For example: `{ node = { port = 9100; }; k3s = { port = 10249; }; }`

## Remote deployment via Colmena

This repository uses [Colmena](https://github.com/zhaofengli/colmena) to deploy NixOS configurations to remote hosts.
Colmena supports both local and remote deployment, and hosts can be targeted by roles as well as their name.
Remote connection properties are defined in the `flake.hosts.<hostname>.deployment` attribute set, and implementation
can be found in the `modules/hosts/<hostname>/default.nix` file. This magic deployment logic lives in the
[./m/f-p/colmena.nix](modules/flake-parts/colmena.nix) file.

> [!NOTE]
> I've made some pretty ugly hacks to make Colmena work with this repository to support multiple nixpkg versions
> for different hosts, and to support both stable and unstable packages.

```bash
# Deploy to all hosts
colmena apply

# Deploy to a specific host
colmena apply --on <hostname>

# Deploy to all hosts with the "server" tag
colmena apply --on @server

# Apply changes to the current host (useful for local development)
colmena apply-local --sudo
```

## Deterministic UIDs and GIDs

Since this configuration is used across multiple systems, it is important to
ensure that user and group IDs are consistent across all systems for services
like NFS. This module provides a way to define deterministic UIDs and GIDs
for users and groups, ensuring that they are assigned the same IDs on all systems.

The configuration is defined in the `users.deterministicIds` option, where you can
specify the expected UID and GID values for each user and group. If a user or
group is used on the system without specifying a UID/GID, this module will assign
the corresponding IDs defined here, or show an error if the definition is missing.

This pattern is based on oddlama's NixOS configuration, which can be found linked below.

The definition file is located at: [./modules/core/deterministic-uids/users.nix](./modules/core/deterministic-uids/users.nix)

## Automatic import

Nix files (they're all flake-parts modules) are automatically imported.
Nix files prefixed with an underscore are ignored.
No literal path imports are used.
This means files can be moved around and nested in directories freely.

> [!NOTE]
> This pattern has been the inspiration of [an auto-imports library, import-tree](https://github.com/vic/import-tree).

## Generated files

The following files in this repository are generated and checked
using [the _files_ flake-parts module](https://github.com/mightyiam/files):

- `.gitignore`
- `LICENSE`
- `README.md`
- `.github/workflows/check.yml`
- `docs/unifi-frr-bgp-dev.conf`
- `docs/unifi-frr-bgp-prod.conf`

## Running checks on GitHub Actions

Running this repository's flake checks on GitHub Actions is merely a bonus
and possibly more of a liability.

Workflow files are generated using
[the _files_ flake-parts module](https://github.com/mightyiam/files).

For better visibility, a job is spawned for each flake check.
This is done dynamically.

To prevent runners from running out of space,
The action [Nothing but Nix](https://github.com/marketplace/actions/nothing-but-nix)
is used.

See [`modules/meta/ci.nix`](modules/meta/ci.nix).

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
- [mightyiam/infra](https://github.com/mightyiam/infra)
- [vic/vix](https://github.com/vic/vix)
- [drupol/infra](https://github.com/drupol/infra/tree/master)

### Other inspirational nix configs:

- [oddlama/nix-config](https://github.com/oddlama/nix-config/)
- [JManch/nixos](https://github.com/JManch/nixos)
- [akirak/homelab](https://github.com/akirak/nix-config/)
- [pim/nix-config](https://git.kun.is/pim/nixos-configs) & [pim's kubernetes configs](https://git.kun.is/home/kubernetes-deployments)

### Notable References:

- [Dendritic Configuration Pattern](https://github.com/mightyiam/dendritic)
- [colmena](https://github.com/zhaofengli/colmena)
- [agenix](https://github.com/ryantm/agenix) & [agenix-rekey](https://github.com/oddlama/agenix-rekey)
- [flake-parts](https://flake.parts/)
