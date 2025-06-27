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

# sini/nix-config

Jason Bowman's [Nix](https://nix.dev)-powered "IT infrastructure" repository

> [!NOTE]
> I hope you find this helpful.
> If you have any questions or suggestions for me, feel free to use the discussions feature or contact me.

## Origin of the dendritic pattern

This repository follows [the dendritic pattern](https://github.com/mightyiam/dendritic)
and happens to be the place in which it was discovered by its author.

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
