# Fleet Summary

## Topology

- **2** environments, **9** hosts, **35** users
- Scope chain: flake → fleet → cluster → user → host → environment → flake-system → flake-parts
- Trace entries: 3500

## Environments

| Environment | Hosts | Host Count | Users |
| ------------- | ------- | ------------ | ------- |
| dev | bitstream, blade, cortex, patch, slab | 5 | 15 |
| prod | axon-01, axon-02, axon-03, uplink | 4 | 20 |

## Aspects by Host

| Host | Aspect Count | Aspects |
| ------ | -------------- | --------- |
| bitstream | 4 | agenix/bitstream, bitstream, insecure-predicate/os, unfree-predicate/os |
| blade | 5 | agenix/blade, blade, host/resolve(dev-gui), insecure-predicate/os, unfree-predicate/os |
| cortex | 5 | agenix/cortex, cortex, host/resolve(dev-gui), insecure-predicate/os, unfree-predicate/os |
| patch | 1 | host/resolve(darwin-workstation) |
| slab | 0 |  |
| axon-01 | 4 | agenix/axon-01, axon-01, insecure-predicate/os, unfree-predicate/os |
| axon-02 | 4 | agenix/axon-02, axon-02, insecure-predicate/os, unfree-predicate/os |
| axon-03 | 4 | agenix/axon-03, axon-03, insecure-predicate/os, unfree-predicate/os |
| uplink | 4 | agenix/uplink, insecure-predicate/os, unfree-predicate/os, uplink |

## Pipes

| Pipe | Scope Boundary | Producers | Collectors |
| ------ | ---------------- | ----------- | ------------ |
| age-secrets | environment: dev | bitstream, blade, cortex, patch |  |
| age-secrets | environment: prod | axon-01, axon-02, axon-03, uplink |  |
| cache | environment: dev | bitstream, blade, cortex, patch |  |
| cache | environment: prod | axon-01, axon-02, axon-03, uplink |  |
| firewall | environment: dev | bitstream, blade, cortex |  |
| firewall | environment: prod | axon-01, axon-02, axon-03, uplink |  |
| homeLinux | environment: dev | bitstream, blade, cortex, patch, slab |  |
| homeLinux | environment: prod | axon-01, axon-02, axon-03, uplink |  |
| host-addrs | environment: dev | bitstream, blade, cortex, patch |  |
| host-addrs | environment: prod | axon-01, axon-02, axon-03, uplink |  |
| nix-builders | environment: dev | bitstream, cortex |  |
| nix-builders | environment: prod | axon-01, axon-02, axon-03, uplink |  |
| nixpkgs-overlays | environment: dev | bitstream, blade, cortex, patch, slab |  |
| nixpkgs-overlays | environment: prod | axon-01, axon-02, axon-03, uplink |  |
| os | environment: dev | bitstream, blade, cortex, patch, slab |  |
| os | environment: prod | axon-01, axon-02, axon-03, uplink |  |
| persist | environment: dev | bitstream, blade, cortex, patch |  |
| persist | environment: prod | axon-01, axon-02, axon-03, uplink |  |
| persistHome | environment: dev | bitstream, blade, cortex, patch, slab |  |
| persistHome | environment: prod | axon-01, axon-02, axon-03, uplink |  |
| bgp-peers | environment: dev |  | bitstream, blade, cortex, patch, slab |
| bgp-peers | environment: prod | axon-01, axon-02, axon-03, uplink | axon-01, axon-02, axon-03, uplink |
| container-registries | environment: dev |  | bitstream, blade, cortex, patch, slab |
| container-registries | environment: prod | uplink | axon-01, axon-02, axon-03 |
| k3s-nodes | environment: dev |  | bitstream, blade, cortex, patch, slab |
| k3s-nodes | environment: prod | axon-01, axon-02, axon-03 | uplink |
| ollama-endpoints | environment: dev | cortex | bitstream, blade, patch, slab |
| ollama-endpoints | environment: prod | uplink | axon-01, axon-02, axon-03 |
| prometheus-targets | environment: dev |  | bitstream, blade, cortex, patch, slab |
| prometheus-targets | environment: prod | uplink | axon-01, axon-02, axon-03 |
| thunderbolt-mesh-peers | environment: dev |  | bitstream, blade, cortex, patch, slab |
| thunderbolt-mesh-peers | environment: prod | axon-01, axon-02, axon-03 | uplink |
| vault-peers | environment: dev |  | bitstream, blade, cortex, patch, slab |
| vault-peers | environment: prod |  | axon-01, axon-02, axon-03, uplink |
| cacheHome | environment: dev | blade, cortex, patch, slab |  |
| cacheHome | environment: prod | uplink |  |
| codium-extensions | environment: dev | blade, cortex, patch, slab |  |
| codium-settings | environment: dev | blade, cortex, patch, slab |  |
| homeDarwin | environment: dev | blade, cortex, patch, slab |  |
| homeManagerModules | environment: dev | blade, cortex, patch, slab |  |
| homebrew-cask | environment: dev | blade, cortex, patch |  |
| replicateHome | environment: dev | blade, cortex, patch, slab |  |
| stylix-hm | environment: dev | blade, cortex, patch |  |
| gpu-claims | environment: dev | cortex |  |
| microvm-guests | environment: dev | cortex |  |
| droid | environment: dev | slab |  |
| media-scratch-exports | environment: prod | axon-01 |  |
| service-domains | environment: prod | uplink |  |
| syncthing-peers | environment: prod | uplink |  |

## Policies

| Policy | Fires at |
| -------- | ---------- |
| flake-to-systems | flake |
| to-fleet | flake |
| apps-to-flake | flake-system |
| checks-to-flake | flake-system |
| devShells-to-flake | flake-system |
| legacyPackages-to-flake | flake-system |
| packages-to-flake | flake-system |
| system-to-flake-parts | flake-system |
| devshell-to-flake-parts | flake-parts |
| fleet-to-envs | fleet |
| env-to-hosts | environment |
| collect-bgp-peers | host |
| collect-container-registries | host |
| collect-host-addrs | host |
| collect-k3s-nodes | host |
| collect-ollama-endpoints | host |
| collect-prometheus-targets | host |
| collect-thunderbolt-mesh-peers | host |
| collect-vault-peers | host |
| env-users | host |
| host-modules-capture | host |
| host-to-hm-users | host |
| os-to-host | host |
| broadcast-syncthing-hub-shares | user |
| broadcast-syncthing-peers | user |
| broadcast-syncthing-peers-to-hub | user |
| expose-resolved-users | user |
| hm-user-detect | user |
| homeAarch64-to-hm | user |
| homeDarwin-to-hm | user |
| host-aspects-project | user |
| primary-user-for-owner | user |
| user-to-host | user |
| drop-user-to-host-on-droid | host |
| host-to-droidHm-users | host |
| droidHm-user-detect | user |
| homeLinux-to-hm | user |
| user-aspect-auto-include | user |
| env-to-clusters | environment |
| cluster-aspect | cluster |
| cluster-collect-container-registries | cluster |
| cluster-collect-k3s-nodes | cluster |
| cluster-collect-media-scratch-exports | cluster |
| cluster-to-nixidy | cluster |
| broadcast-hub-peer | host |