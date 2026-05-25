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
| [uplink](modules/hosts/uplink/)       | Ryzen 5950X (16/32) - 128GB - 10gbe - Intel Arc A310 - AV1 Transcoding / Router / k8s control           |   Server    |  x86_64-linux  |
| [axon-01](modules/hosts/axon-01/)     | MINISFORUM Venus UM790 Pro - Ryzen 9 7940HS (8/16) - 64GB - 2.5gbe - Radeon 780M - k8s node             |   Server    |  x86_64-linux  |
| [axon-02](modules/hosts/axon-02/)     | MINISFORUM Venus UM790 Pro - Ryzen 9 7940HS (8/16) - 64GB - 2.5gbe - Radeon 780M - k8s node             |   Server    |  x86_64-linux  |
| [axon-03](modules/hosts/axon-03/)     | MINISFORUM Venus UM790 Pro - Ryzen 9 7940HS (8/16) - 64GB - 2.5gbe - Radeon 780M - k8s node             |   Server    |  x86_64-linux  |
| [bitstream](modules/hosts/bitstream/) | GMKtec M6 - Ryzen 5 6600H (8/16) - 64GB - 2.5gbe - Radeon 660M - k8s node                               |   Server    |  x86_64-linux  |
| [cortex](modules/hosts/cortex/)       | Ryzen 9950X3D (16/32) - 128GB - 10gbe - 7900XTX + 3090TI - Hybrid ML Server/Workstation/VFIO Gaming Rig | Workstation |  x86_64-linux  |
| [spike](modules/hosts/spike/)         | Razer Blade 16 (2023) - NixOS - 32GB ram - RTX 4090 (mobile)                                            |   Laptop    |  x86_64-linux  |
| [patch](modules/hosts/patch/)         | M1 Macbook Air - 16gb / 1tb - macOS Sequoia 15.2                                                        |   Laptop    | aarch64-darwin |
| [vault](modules/hosts/vault/)         | 1tb NVME + 80tb NFS - 2x1gbe + 2.5gbe                                                                   |     NAS     |  x86_64-linux  |

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
