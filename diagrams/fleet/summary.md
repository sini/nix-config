# Fleet Summary

## Topology

- **2** environments, **11** hosts, **12** users
- Scope chain: flake → fleet → cluster → user → host → environment →
  flake-system → flake-parts
- Trace entries: 1615

## Environments

| Environment | Hosts                             | Host Count | Users |
| ----------- | --------------------------------- | ---------- | ----- |
| dev         | bitstream, blade, cortex, patch   | 4          | 8     |
| prod        | axon-01, axon-02, axon-03, uplink | 4          | 4     |

## Aspects by Host

| Host      | Aspect Count | Aspects                                                                 |
| --------- | ------------ | ----------------------------------------------------------------------- |
| bitstream | 4            | agenix/bitstream, bitstream, insecure-predicate/os, unfree-predicate/os |
| blade     | 4            | agenix/blade, blade, insecure-predicate/os, unfree-predicate/os         |
| cortex    | 4            | agenix/cortex, cortex, insecure-predicate/os, unfree-predicate/os       |
| patch     | 0            |                                                                         |
| axon-01   | 4            | agenix/axon-01, axon-01, insecure-predicate/os, unfree-predicate/os     |
| axon-02   | 4            | agenix/axon-02, axon-02, insecure-predicate/os, unfree-predicate/os     |
| axon-03   | 4            | agenix/axon-03, axon-03, insecure-predicate/os, unfree-predicate/os     |
| uplink    | 4            | agenix/uplink, insecure-predicate/os, unfree-predicate/os, uplink       |
| axon-01   | 4            | agenix/axon-01, axon-01, insecure-predicate/os, unfree-predicate/os     |
| axon-02   | 4            | agenix/axon-02, axon-02, insecure-predicate/os, unfree-predicate/os     |
| axon-03   | 4            | agenix/axon-03, axon-03, insecure-predicate/os, unfree-predicate/os     |

## Pipes

| Pipe                   | Scope Boundary    | Producers                                                    | Collectors                                                   |
| ---------------------- | ----------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| age-secrets            | environment: dev  | bitstream, blade, cortex, patch                              |                                                              |
| age-secrets            | environment: prod | axon-01, axon-02, axon-03, uplink, axon-01, axon-02, axon-03 |                                                              |
| age-secrets            | cluster: axon     | axon-01, axon-02, axon-03, axon-01, axon-02, axon-03         |                                                              |
| cache                  | environment: dev  | bitstream, blade, cortex, patch                              |                                                              |
| cache                  | environment: prod | axon-01, axon-02, axon-03, uplink, axon-01, axon-02, axon-03 |                                                              |
| cache                  | cluster: axon     | axon-01, axon-02, axon-03, axon-01, axon-02, axon-03         |                                                              |
| firewall               | environment: dev  | bitstream, cortex                                            |                                                              |
| firewall               | environment: prod | axon-01, axon-02, axon-03, uplink, axon-01, axon-02, axon-03 |                                                              |
| firewall               | cluster: axon     | axon-01, axon-02, axon-03, axon-01, axon-02, axon-03         |                                                              |
| homeLinux              | environment: dev  | bitstream, blade, cortex, patch                              |                                                              |
| homeLinux              | environment: prod | axon-01, axon-02, axon-03, uplink, axon-01, axon-02, axon-03 |                                                              |
| homeLinux              | cluster: axon     | axon-01, axon-02, axon-03, axon-01, axon-02, axon-03         |                                                              |
| host-addrs             | environment: dev  | bitstream, blade, cortex, patch                              |                                                              |
| host-addrs             | environment: prod | axon-01, axon-02, axon-03, uplink, axon-01, axon-02, axon-03 |                                                              |
| host-addrs             | cluster: axon     | axon-01, axon-02, axon-03, axon-01, axon-02, axon-03         |                                                              |
| nix-builders           | environment: dev  | bitstream, cortex                                            |                                                              |
| nix-builders           | environment: prod | axon-01, axon-02, axon-03, uplink, axon-01, axon-02, axon-03 |                                                              |
| nix-builders           | cluster: axon     | axon-01, axon-02, axon-03, axon-01, axon-02, axon-03         |                                                              |
| os                     | environment: dev  | bitstream, blade, cortex, patch                              |                                                              |
| os                     | environment: prod | axon-01, axon-02, axon-03, uplink, axon-01, axon-02, axon-03 |                                                              |
| os                     | cluster: axon     | axon-01, axon-02, axon-03, axon-01, axon-02, axon-03         |                                                              |
| persist                | environment: dev  | bitstream, blade, cortex, patch                              |                                                              |
| persist                | environment: prod | axon-01, axon-02, axon-03, uplink, axon-01, axon-02, axon-03 |                                                              |
| persist                | cluster: axon     | axon-01, axon-02, axon-03, axon-01, axon-02, axon-03         |                                                              |
| persistHome            | environment: dev  | bitstream, blade, cortex, patch                              |                                                              |
| persistHome            | environment: prod | axon-01, axon-02, axon-03, uplink, axon-01, axon-02, axon-03 |                                                              |
| persistHome            | cluster: axon     | axon-01, axon-02, axon-03, axon-01, axon-02, axon-03         |                                                              |
| bgp-peers              | environment: dev  |                                                              | bitstream, blade, cortex, patch                              |
| bgp-peers              | environment: prod | axon-01, axon-02, axon-03, uplink, axon-01, axon-02, axon-03 | axon-01, axon-02, axon-03, uplink, axon-01, axon-02, axon-03 |
| bgp-peers              | cluster: axon     | axon-01, axon-02, axon-03, axon-01, axon-02, axon-03         | axon-01, axon-02, axon-03, axon-01, axon-02, axon-03         |
| k3s-nodes              | environment: dev  |                                                              | bitstream, blade, cortex, patch                              |
| k3s-nodes              | environment: prod | axon-01, axon-02, axon-03, axon-01, axon-02, axon-03         | uplink                                                       |
| k3s-nodes              | cluster: axon     | axon-01, axon-02, axon-03, axon-01, axon-02, axon-03         | axon-01, axon-02, axon-03, axon-01, axon-02, axon-03         |
| ollama-endpoints       | environment: dev  | cortex                                                       | bitstream, blade, patch                                      |
| ollama-endpoints       | environment: prod | uplink                                                       | axon-01, axon-02, axon-03, axon-01, axon-02, axon-03         |
| ollama-endpoints       | cluster: axon     |                                                              | axon-01, axon-02, axon-03, axon-01, axon-02, axon-03         |
| prometheus-targets     | environment: dev  |                                                              | bitstream, blade, cortex, patch                              |
| prometheus-targets     | environment: prod | uplink                                                       | axon-01, axon-02, axon-03, axon-01, axon-02, axon-03         |
| prometheus-targets     | cluster: axon     |                                                              | axon-01, axon-02, axon-03, axon-01, axon-02, axon-03         |
| thunderbolt-mesh-peers | environment: dev  |                                                              | bitstream, blade, cortex, patch                              |
| thunderbolt-mesh-peers | environment: prod | axon-01, axon-02, axon-03, axon-01, axon-02, axon-03         | uplink                                                       |
| thunderbolt-mesh-peers | cluster: axon     | axon-01, axon-02, axon-03, axon-01, axon-02, axon-03         | axon-01, axon-02, axon-03, axon-01, axon-02, axon-03         |
| vault-peers            | environment: dev  |                                                              | bitstream, blade, cortex, patch                              |
| vault-peers            | environment: prod |                                                              | axon-01, axon-02, axon-03, uplink, axon-01, axon-02, axon-03 |
| vault-peers            | cluster: axon     |                                                              | axon-01, axon-02, axon-03, axon-01, axon-02, axon-03         |
| homeDarwin             | environment: dev  | blade, cortex, patch                                         |                                                              |
| shuo                   | environment: dev  | blade, cortex                                                |                                                              |
| sini                   | environment: dev  | blade, cortex                                                |                                                              |
| spoke                  | environment: prod | axon-01, axon-02, axon-03, uplink, axon-01, axon-02, axon-03 |                                                              |
| spoke                  | cluster: axon     | axon-01, axon-02, axon-03, axon-01, axon-02, axon-03         |                                                              |
| service-domains        | environment: prod | uplink                                                       |                                                              |

## Policies

| Policy                         | Fires at     |
| ------------------------------ | ------------ |
| flake-to-systems               | flake        |
| to-fleet                       | flake        |
| apps-to-flake                  | flake-system |
| checks-to-flake                | flake-system |
| devShells-to-flake             | flake-system |
| legacyPackages-to-flake        | flake-system |
| packages-to-flake              | flake-system |
| system-to-flake-parts          | flake-system |
| devshell-to-flake-parts        | flake-parts  |
| fleet-to-envs                  | fleet        |
| env-to-hosts                   | environment  |
| collect-bgp-peers              | host         |
| collect-host-addrs             | host         |
| collect-k3s-nodes              | host         |
| collect-ollama-endpoints       | host         |
| collect-prometheus-targets     | host         |
| collect-thunderbolt-mesh-peers | host         |
| collect-vault-peers            | host         |
| env-users                      | host         |
| host-to-hm-users               | host         |
| os-to-host                     | host         |
| hm-user-detect                 | user         |
| homeAarch64-to-hm              | user         |
| homeDarwin-to-hm               | user         |
| user-to-host                   | user         |
| homeLinux-to-hm                | user         |
| user-aspect-auto-include       | user         |
| env-to-clusters                | environment  |
| cluster-collect-k3s-nodes      | cluster      |
| cluster-to-hosts               | cluster      |
| cluster-to-nixidy              | cluster      |
