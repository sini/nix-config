# Wrapper Modules Integration

## Status: Design / Research

This document tracks the investigation into integrating
[nix-wrapper-modules](https://github.com/BirdeeHub/nix-wrapper-modules) with our
existing feature system to expose user-level features as standalone
`nix run .#<app>` packages.

## Contents

- [observations.md](./observations.md) — Analysis of our feature system, the
  wrapper-modules approach, and an adapter strategy
- [gitkraken-case-study.md](./gitkraken-case-study.md) — Deep dive into wrapping
  a real HM-dependent feature (gitkraken), obstacles, and three approaches
- [prototype-prompt.md](./prototype-prompt.md) — Handoff prompt for the
  nix-wrapper-modules fork session (Approach C: generalized HM adapter)
