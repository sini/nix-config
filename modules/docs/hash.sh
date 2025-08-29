#!/usr/bin/env bash
USER=MichaelAquilina
REPO=zsh-auto-notify
COMMIT=3e9bce0072240b1009e5ab380365453c3b243c62
nix hash convert --hash-algo sha256 --to sri $(nix-prefetch-url --unpack https://github.com/${USER}/${REPO}/archive/${COMMIT}.tar.gz)
