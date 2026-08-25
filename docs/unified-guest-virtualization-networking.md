# Design Specification: Unified Guest Virtualization Networking

**Status**: Proposed
**Author**: Sini / Antigravity Pair
**Target Date**: 2026-08
**Scope**: Den Virtualization Engine (`modules/den/aspects/virtualization/`)

---

## 1. Overview & Motivation

### 1.1 Problem Statement
Currently, guest networking across virtualized workloads exhibits architectural inconsistencies and technical debt:
1. **Libvirt Networking Technical Debt**: `modules/den/aspects/virtualization/libvirt.nix` relies on imperative shell scripts (`systemd.services.libvirt-networks`) executing `virsh net-define` and `virsh net-start` after an arbitrary `sleep 5` delay, seeding a static XML network with a hardcoded `192.168.122.1/24` subnet.
2. **Aspect Reusability Violations**: Historically, host-specific guest IP addresses were hardcoded inside aspect files rather than resolved from entity contracts.
3. **Dual Network Stacks**: MicroVM guests (`microvm-guests.nix`) and Libvirt domains (`libvirt.nix`) use disparate networking backends (systemd-networkd vs. libvirtd/dnsmasq NAT), preventing unified performance tuning (Jumbo Frames MTU 9000, BBR congestion control, TCP window scaling) across all hypervisors.

### 1.2 Objectives
* **Declarative Entity-Driven Contracts**: Standardize guest networking configuration so both MicroVM and Libvirt guest entities declare interface parameters (`ipv4`, `mac`, `mtu`, `attachment`) under standard `networking.interfaces`.
* **Zero Imperative Shell Scripts**: Eliminate `virsh net-define`, `virsh net-start`, `sleep 5`, and static XML strings from NixOS declarations.
* **Unified Host Routing & Bridging**: Drive host TAP/vnet interface creation, bridge enslavement (`br0`), and `systemd-networkd` host routes dynamically from the Den fleet graph.
* **Consistent High-Performance Profile**: Enforce MTU 9000 Jumbo Frames, BBR TCP congestion control, and TCP window scaling across all inter-VM interconnections.

---

## 2. Architecture & Design Principles

```
                              ┌──────────────────────────────────────┐
                              │  Guest Host Entity (e.g. cortex-cuda)│
                              │  networking.interfaces.vm-cuda = {   │
                              │    ipv4 = [ "10.9.2.2/16" ];          │
                              │    mac  = "02:00:00:01:01:01";       │
                              │  };                                  │
                              └──────────────────┬───────────────────┘
                                                 │
                                                 ▼
                              ┌──────────────────────────────────────┐
                              │     Parent Host (e.g. cortex)        │
                              │  guests.cortex-cuda = childGuest;    │
                              └──────────────────┬───────────────────┘
                                                 │
                                 ┌───────────────┴───────────────┐
                                 ▼                               ▼
                 ┌──────────────────────────────┐ ┌──────────────────────────────┐
                 │ MicroVM Guest Runner Aspect  │ │ Libvirt Guest Runner Aspect  │
                 │ (microvm-guests.nix)         │ │ (libvirt-guests.nix)         │
                 └───────────────┬──────────────┘ └───────────────┬──────────────┘
                                 │                               │
                                 └───────────────┬───────────────┘
                                                 │ (Dynamic Contract Inspection)
                                                 ▼
                              ┌──────────────────────────────────────┐
                              │       Host systemd-networkd          │
                              │  - 30-guest-<vm>-<if>: match <if>    │
                              │  - Route: Destination = <guest-ip>/32│
                              │  - Link:  MTUBytes = 9000            │
                              └──────────────────────────────────────┘
```

### 2.1 The Guest Network Contract
Guest host entities (whether executed via MicroVM or Libvirt QEMU) declare their network interfaces in a host-agnostic manner:

```nix
den.hosts.x86_64-linux.cortex-cuda = {
  networking.interfaces.vm-cuda = {
    ipv4 = [ "10.9.2.2/16" ];
    mac = "02:00:00:01:01:01";
    mtu = 9000;
  };
};
```

### 2.2 Host-Side Dynamic Network Resolution
When a host delivers child guest entities via `guests.<name>`, the host virtualization aspect inspects `children = lib.attrValues (host.guests or { })` to construct declarative `systemd.network.networks` configurations:

```nix
# Reusable host-side guest network generator (shared logic for microvm and libvirt)
systemd.network.networks = lib.mkMerge (
  lib.concatMap (
    vm:
    lib.mapAttrsToList (
      ifName: ifCfg:
      let
        ipv4Addrs = ifCfg.ipv4 or [ ];
        guestIps = map (cidr: lib.head (lib.splitString "/" cidr)) ipv4Addrs;
        mtu = if ifCfg.mtu != null then toString ifCfg.mtu else "9000";
      in
      lib.optionalAttrs (guestIps != [ ]) {
        "30-guest-${vm.name}-${ifName}" = {
          matchConfig.Name = [ ifName "${vm.name}-*" ];
          linkConfig.MTUBytes = mtu;
          routes = map (ip: { Destination = "${ip}/32"; }) guestIps;
        };
      }
    ) (vm.networking.interfaces or { })
  ) children
);
```

### 2.3 Eliminating Libvirt Imperative State
Instead of executing `virsh net-define` and running `dnsmasq` inside `libvirtd`:
1. **Bridge Integration**: Libvirt guests use standard QEMU bridge helper (`qemu-bridge-helper`) to attach `vnet*` TAP interfaces directly to host `br0` or host systemd-networkd managed interfaces.
2. **Systemd-Networkd Dominance**: Host `systemd-networkd` handles IP allocation, routing, MTU, and firewall rules for all guest TAP interfaces (`vm-*`, `vnet*`).
3. **Deprecate `libvirt-networks.service`**: Remove `primaryNetwork` (`default-network.xml`) and `primarybridgeNetwork` (`default-bridge.xml`) from `libvirt.nix`.

---

## 3. High-Performance Network Profile

All guest network interfaces (MicroVM TAP and Libvirt vnet) adhere to a standardized performance profile for host-guest LLM inference streaming (800K context requests):

| Component | Setting | Architectural Purpose |
| :--- | :--- | :--- |
| **MTU** | `9000` (Jumbo Frames) | Minimizes packet fragmentation and CPU interrupt overhead for multi-megabyte prompt streaming. |
| **Congestion Control** | `net.ipv4.tcp_congestion_control = "bbr"` | Replaces Cubic with Google BBR for optimal throughput and low queueing delay. |
| **Packet Scheduler** | `net.core.default_qdisc = "fq"` | Required for BBR pacing. |
| **TCP Window Buffers** | `net.core.rmem_max = 16777216`<br>`net.core.wmem_max = 16777216` | Expands max socket buffer window to 16MB for high bandwidth-delay product links. |
| **Fast Open** | `net.ipv4.tcp_fastopen = 3` | Reduces TCP connection handshake latency for microservice LLM API calls. |

---

## 4. Implementation Phases

### Phase 1: MicroVM Dynamic Network Resolution (Complete)
* Replaced hardcoded IPs in `microvm-guests.nix` with dynamic derivation from guest entity `vm.networking.interfaces`.
* Applied MTU 9000 Jumbo Frames and BBR TCP tuning across host `cortex` and guest `cortex-cuda`.

### Phase 2: Libvirt Guest Contract Alignment
* Update `modules/den/aspects/virtualization/libvirt.nix` to allow `br0` and TAP interface routing via `systemd-networkd`.
* Remove imperative `systemd.services.libvirt-networks` script and static XML files.

### Phase 3: Shared Virtualization Aspect Abstraction
* Extract common guest network resolution logic into a shared Den virtualization helper module (`modules/den/aspects/virtualization/common-guest-network.nix`) consumed by both `microvm-guests.nix` and `libvirt.nix`.

---

## 5. Verification & Compliance

* **Evaluation Integrity**: All NixOS system evaluations (`nix eval .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`) must complete with 0 errors.
* **Aspect Hygiene**: Zero hardcoded IP addresses permitted in aspect definitions under `modules/den/aspects/`.
* **Runtime Verification**: SSH connectivity and `0.2ms` ping response over `10.9.x.x` guest interfaces.
