# Local Helm Charts

This directory contains helm chart definitions managed by
[nixhelm's helmupdater](https://github.com/nix-community/nixhelm). These are
charts not available in the upstream
[nixhelm](https://github.com/nix-community/nixhelm) repository, pinned with
reproducible hashes for use in our nixidy environments.

## Structure

Charts follow the `<repo-name>/<chart-name>/default.nix` convention:

```
charts/
├── rocm/
│   └── amd-gpu/default.nix
└── truecharts/
    └── romm/default.nix
```

Each `default.nix` contains the chart metadata:

```nix
{
  repo = "https://rocm.github.io/k8s-device-plugin/";
  chart = "amd-gpu";
  version = "0.21.0";
  chartHash = "sha256-...";
}
```

## Adding a new chart

```bash
helmupdater init <repo-url> <repo-name>/<chart-name>
```

For example:

```bash
helmupdater init "https://rocm.github.io/k8s-device-plugin/" "rocm/amd-gpu"
```

Then `git add` the new chart so Nix flakes can see it, and reference it in your
nixidy module:

```nix
{ charts, ... }:
{
  helm.releases.my-release = {
    chart = charts.<repo-name>.<chart-name>;
  };
}
```

## Updating charts

Update all charts to their latest versions:

```bash
helmupdater update-all
```

Update a single chart:

```bash
helmupdater update <repo-name>/<chart-name>
```

Rehash a chart without changing the version:

```bash
helmupdater rehash <repo-name>/<chart-name>
```

## How it works

The flake-parts module in `modules/flake-parts/helm-charts.nix` uses
[haumea](https://github.com/nix-community/haumea) to load all chart definitions
from this directory and builds them into derivations via `nix-kube-generators`.
These are merged with upstream nixhelm charts and made available to nixidy
environments as the `charts` argument.

## Automated updates

A GitHub Action runs `helmupdater update-all` daily alongside
`nix flake update`, creating a PR with any version bumps.
