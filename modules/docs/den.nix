{ dag, ... }:
{
  flake.readme.den =
    dag.entryBetween [ "automatic-import" ] [ "hosts" ]
      # markdown
      ''
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
        | `network/` | networking (systemd-networkd), openssh, tailscale, network-boot |
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

      '';
}
