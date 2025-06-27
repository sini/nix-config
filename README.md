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

Jason Bowman's [NixOS](https://nix.dev) homelab and workstation configuration repository.

> [!NOTE]
> If you have any questions or suggestions, feel free to contact me via e-mail `jason <at> json64 <dot> dev`.

## Remote deployment via Colmena

This repository uses [Colmena](https://github.com/zhaofengli/colmena) to deploy NixOS configurations to remote hosts.
Colmena supports both local and remote deployment, and hosts can be targeted by tags as well as their name.
Remote connection properties are defined in the `flake.hosts.<hostname>.deployment` attribute set, and implementation
can be found in the `modules/hosts/<hostname>/default.nix` file. This magic deployment logic lives in the
[./m/f-p/colmena.nix](modules/flake-parts/colmena.nix) file.

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
