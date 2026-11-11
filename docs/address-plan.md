# The address plan: the /56, host tokens and DHCP reservations

Status: **decided v0.2** (2026-11-11). The owner ruled on every open question
(§6), and stage 1 is built from this text. It was written against `main` at
`9f7d4f02`. Stage 1 covers four things: DHCP reservations from den, stable IPv6
host parts, a convention for slicing the /56, and the cluster's ULA moved into
the site's. Stage 2, public IPv6 for individual services, is out of scope. §4
lists only what it needs from this plan.

## 1. Problem

The fleet's IPv4 plan lives in den. Its IPv6 plan lives nowhere. Measured
read-only on 2026-11-11 (controller `rest/networkconf`,
`ssh <host> ip -6 addr`):

**The /56 is sliced by the controller's auto-assignment, not by a rule.** The
WAN takes a /56 by DHCPv6-PD (`wan_dhcpv6_pd_size: 56`), now
`2001:5a8:608c:b600::/56`. `Default` (prod, 10.10.0.0/16) has prefix id `00`
(`b600::/64`). `dev` (10.9.0.0/16) has `01` (`b601::/64`, read from cortex's and
bitstream's SLAAC addresses). A third network would take whatever id comes next.

**Hosts' global addresses are whatever they happen to get:**

| Host      | Global IPv6 on its LAN link today                                   | Source               |
| --------- | ------------------------------------------------------------------- | -------------------- |
| uplink    | `b600::271/128`, `b600:268a:7ff:fee0:a8b0/64`                       | DHCPv6 lease, EUI-64 |
| axon-01   | `b600::67f/128` only                                                | DHCPv6 (SLAAC off)   |
| cortex    | `b601:12ff:e0ff:feb6:6b2b/64`, `b601:3b0:c4f8:54f9:db5f/64`         | EUI-64, temporary    |
| bitstream | `b601:e03a:…/64`, a temporary, and a static `2001:5a8:608c:4a00::1` | EUI-64, temp, den    |

bitstream's static address comes from a prefix the site no longer holds. It has
been in den since 2025-09 (`docs/ipv6-prefix-translation.md` names it
"current"). So the delegated /56 has most likely changed at least once (`…4a00`
→ `…b600`, within the same /48). That is an inference from den's history, not a
measurement. How often it changes is unmeasured, and stays so: the prefix is not
logged (§6). Nothing in den may therefore hold the delegated prefix.

**The ULAs disagree.** prod's `networks.default.ipv6_cidr` is RFC 4193:
`fd3d:f136:2e4e::/64`, `fd` plus 40 bits of sha256("json64.dev/prod")
(`environments/prod.nix`). Blocky's `::53` sits in it. dev's is `fd64:1:1::/64`,
and cortex carries `fd64:0:1::5/64`. Both are leftovers of the unbuilt NPTv6
plan, and neither has a random global ID. The cluster's `fdfd:cafe::/48` (pods,
services, fabric loopbacks, `clusters/axon.nix`) is a third, cluster-internal
space.

**The controller holds no reservations from den.** Static hosts sit in what is
now the DHCP pool (10.X.1.1 onward): 10.10.10.1-4, 10.10.11.1, 10.9.1.1,
10.9.2.1-2. Only the absence of a lease keeps the pool from handing one out.
Client records (`rest/user`, go-unifi `Client`) carry `mac`, `name`,
`network_id`, `use_fixedip` and `fixed_ip`. They have no fixed-IPv6 field, so
IPv6 stability has to come from the hosts.

**MACs are mostly not in den.** nixos-facter records no hardware addresses: zero
MAC strings in all seven `hosts/*/facter.json`. `networking.interfaces.<n>.mac`
is set for uplink and cortex (bridges adopt it). The guests' tap MACs are fixed
in den (`02:00:00:01:01:01`, `02:00:00:01:02:01`). The axons and bitstream
declare none. bitstream's `bond0` runs on a networkd-generated, locally
administered MAC (`e2:3a:b3:99:7c:4b`).

## 2. Design

### 2.1 The /56: subnet id = environment nibble, purpose nibble

A /56 leaves an 8-bit subnet id `s`, so there are 256 /64s. The id is two hex
digits, and each digit means one thing:

```
s = E·16 + P        /64 = <delegated /56>:<s as two hex digits>::/64
E  environment   = den.environments.<e>.ipv6Nibble, declared   (prod 0, dev 1; 2–e future envs; f infra)
P  purpose       = 0 LAN · 1 cluster LB services · 2 cluster (pods, services, fabric) · 3–f reserved
```

| Slice | prod (E=0)   | dev (E=1)    | Use                                        |
| ----- | ------------ | ------------ | ------------------------------------------ |
| P=0   | `…b600::/64` | `…b610::/64` | the environment's LAN (`networks.default`) |
| P=1   | `…b601::/64` | `…b611::/64` | stage 2: LoadBalancer addresses            |
| P=2   | `…b602::/64` | `…b612::/64` | the cluster's slice; only its ULA is used  |
| E=f   | `…b6f0::/60` |              | gateway-side transit and infra             |

Why the environment is the high nibble: each environment is then one /60
(`…b600::/60` prod, `…b610::/60` dev). That is the unit that firewall policy,
`unifi.networkPolicies` and any later per-env delegation address. The reverse
layout (purpose high) keeps today's ids, but it scatters an environment over
sixteen /64s. `E` is declared per environment (`ipv6Nibble`, an integer 0–15),
not derived from its `id`: the id is Cilium's cluster id and a counter, the
nibble an address. A nibble above 15 is an evaluation error (the option's type),
and two environments on one nibble fail the `address-plan-slices` check.

**Mapping today:** `Default` 00 → (prod, LAN), no change. `dev` 01 decodes as
(prod, LB), so it **moves to 10**. On `dev`, the unifi workspace sets
`ipv6_pd_auto_prefixid_enabled = false` and `ipv6_pd_prefixid = "10"` (go-unifi
`network.generated.go`: `^$|[a-fA-F0-9]{1,4}`). On `Default`, it pins `"0"` the
same way, so no future network auto-takes it. Both fields go into the existing
`renderNetworkDns` body (`fieldsOf`), which already PUTs the live network with
declared fields laid over it. `ipv6_pd_auto_prefixid_enabled` joins `required`'s
precondition. `ipv6_pd_prefixid` does not, since a network on auto may not carry
it. The move renumbers dev's GUAs once. Nothing in den pins one (bitstream's
`4a00` address is removed, §2.2).

**ULA, the same slicing:** one site /48, `fd3d:f136:2e4e::/48`, prod's existing
global ID, kept so Blocky's `::53` does not move. Subnet `00ss` mirrors the GUA
subnet id: `fd3d:f136:2e4e:00ss::/64`. prod LAN stays `fd3d:f136:2e4e::/64`
exactly. dev LAN becomes `fd3d:f136:2e4e:10::/64`, replacing `fd64:1:1::/64`,
and cortex's `fd64:0:1::5` is dropped. Each environment's
`networks.default.ipv6_cidr` is computed from the site /48 and `s`, so it is no
longer written by hand. Swap the /56 for `fd3d:f136:2e4e:0000::/56` and a GUA
becomes its ULA. The rest of the /48 (`01xx`–`ffxx`) is reserved.

**The cluster's ULA moves into the site's** (§6 Q4). `fdfd:cafe::/48` is
replaced by the cluster environment's P=2 /64, `fd3d:f136:2e4e:2::/64` for
prod's axon. Its three uses keep their old selectors, shifted one group right:

| Use              | Was                      | Becomes                       |
| ---------------- | ------------------------ | ----------------------------- |
| pods             | `fdfd:cafe:0:1::/96`     | `fd3d:f136:2e4e:2:1::/96`     |
| services         | `fdfd:cafe:0:8001::/112` | `fd3d:f136:2e4e:2:8001::/112` |
| fabric loopbacks | `fdfd:cafe:0:ff::N/128`  | `fd3d:f136:2e4e:2:ff::N/128`  |

The pod pool stays a /96 with /112 per node: kube-controller-manager refuses a
node mask more than 16 bits longer than the cluster CIDR, so a /64 pool cannot
carry /112 nodes. No workload depends on pod IPv6 today, and the addresses are
provisional.

### 2.2 Host tokens: the IPv4, octet for octet

A host's interface identifier (IID) on a LAN is its IPv4 address on that LAN.
Each decimal octet is written as one 16-bit group:

```
uplink      10.10.10.1  → ::10:10:10:1   → 2001:5a8:608c:b600:10:10:10:1, fd3d:f136:2e4e:0:10:10:10:1
axon-01     10.10.10.2  → ::10:10:10:2
uplink-dev  10.10.11.1  → ::10:10:11:1
cortex      10.9.2.1    → ::10:9:2:1     → …b610:10:9:2:1,  fd3d:f136:2e4e:10:10:9:2:1
```

The address reads as the host's IPv4. It is unique site-wide, not just per LAN,
because den's IPv4s are unique. The first group is never zero (the first octet
is 10), so host IIDs are disjoint from the zero-headed space. That space holds
the DHCPv6 pool (`::2`–`::7d1`) and service addresses (Blocky's `::53`), and
stage 2 LB IIDs go there too. No token falls in RFC 5453's reserved IIDs.

**Mechanism.** den computes `tokenOf (addressOn "default" host)`. The networking
aspect writes two things from it:

- GUA: `[IPv6AcceptRA] Token = static:<token>` (systemd ≥ 250. The old
  `[Network] IPv6Token=` is gone from systemd.network(5) in 262). SLAAC then
  forms `<prefix>:<token>` from whatever prefix the router announces, so den
  never holds the prefix. The host needs `UseAutonomousPrefix` on. The axons
  have it off today (`acceptRAAutonomousPrefix = false`) and turn it back on.
  `privacyExtensions` stays per host. The axons keep `"no"`, so the token
  address is their one global source and Cilium's masquerade source stays warm,
  as their DHCPv6-only setting intended.
- ULA: a static `Address = <env ULA /64>:<token>/64`. The router announces no
  ULA, so SLAAC cannot form it. `ipv6On` used to turn every declared ULA address
  into an RA-sending link (`IPv6SendRA`). The two are now split: token ULAs are
  plain addresses, and a link sends the prefix RA only when its interface
  declares `advertiseUla` (uplink's `enp4s0`, for Blocky's `::53`).

**DHCPv6 vs SLAAC on Default.** `Default` sets M and O (DHCPv6 assignment
`::2`–`::7d1`, SLAAC allowed). networkd starts a DHCPv6 client whenever an RA
carries M (`[IPv6AcceptRA] DHCPv6Client=` defaults to true), whatever `DHCP=`
says. That is why uplink holds `::271` and axon-01 `::67f`. Decided: **den hosts
stop taking DHCPv6 addresses** (`DHCPv6Client = false` on token links). The
token is the one stable GUA, the router's lease is a second address den did not
choose, and the axons' reason for DHCPv6 (one deterministic GUA) is met by the
token. `Default` keeps M and keeps serving DHCPv6 to ordinary clients, and
uplink's RA shortcut, which mirrors M, is unchanged.

**Guests.** uplink-dev and cortex-cuda write their own `20-lan` unit
(`hosts/uplink-dev.nix`, `hosts/cortex-cuda.nix`), not the aspect's. They take
the same `tokenOf` on their own IPv4 and set the same two keys there. Their
parent's bridge only switches frames, so a guest's address is the guest's own.

### 2.3 DHCP reservations: den → `rest/user`, adopted by MAC

For every den host (guests included) with an IPv4 in an environment's
`networks.default.cidr` and a `unifiNetwork`, the unifi workspace renders one
client record:

| Field         | Value                                                                |
| ------------- | -------------------------------------------------------------------- |
| `mac`         | the key: `networking.interfaces.<n>.mac`, or a guest's microvm `mac` |
| `use_fixedip` | `true`                                                               |
| `fixed_ip`    | `addressOn "default" host`                                           |
| `network_id`  | the `rest/networkconf` data source's `_id` for `unifiNetwork`        |
| `name`        | the den host name                                                    |

The intent is to manage `fixed_ip` and `name`. `use_fixedip` and `network_id`
are the switch and scope `fixed_ip` cannot work without. Every other field is
left as it is, using the networks' pattern: the PUT body is the live object with
these fields laid over it, `ignore_server_additions = false`. `unifi-adopt`
imports each declared record from the one live client with that MAC (lowercased)
and refuses two. A MAC the controller has never seen is a POST to `rest/user`.
Destroy only clears `use_fixedip` and never forgets the client.

MAC source: the den option, not facter, which has none. The build declares `mac`
for axon-01..03 and bitstream, read live with `ip -br link`. bitstream also pins
`bond0`'s MAC (networkd `MACAddress=`), so a reinstall cannot regenerate it. A
host with an IPv4 and no MAC is an evaluation error, not a silent skip.
Interfaces outside den (NAS 10.10.10.10, the 10.10.10.100 VIP) are not reserved:
the NAS is not a den host, and the VIP has no MAC of its own.

**MAC changes.** A guest's MAC is den's, and a bridged host's is its NIC's, so
neither changes unless den does. A replaced NIC is a new client. The same apply
must clear the old record's `use_fixedip` and set the new one, and whether the
controller refuses two clients with one `fixed_ip` during that step is
unmeasured (§5). Hosts keep their static configuration. The reservation guards
their address against the pool and documents it on the controller. It never
configures the host, so a wrong MAC costs a reservation, not an outage.

## 3. Acceptance

Each check is an evaluation-time `checks.<system>.*`, following the existing
`unifi-*-render` checks, unless it says live. Every check has a control that
must fail or read non-zero, so an empty render cannot pass.

1. **`address-plan-slices`.** Every (environment, purpose) /64, GUA template and
   ULA, is inside its /56, and no two overlap. Each environment's /60 contains
   only its own slices. Control: a fixture with two environments on one nibble,
   and one with nibble 16, must each throw (`builtins.tryEval`). The real fleet
   must yield exactly 2 × 3 named slices.
2. **`address-plan-tokens`.** Tokens are pairwise distinct across the site, and
   every token has a non-zero first group, which keeps it out of the zero-headed
   DHCPv6 pool. Control: a fixture with a duplicate IPv4 throws. Token counts
   equal the hosts with an IPv4 on that LAN: prod 5 (uplink, axon-01..03,
   uplink-dev), dev 3 (cortex, cortex-cuda, bitstream). The rendered units carry
   them, and exactly one LAN link (uplink's `br0`) sends RAs.
3. **`unifi-reservation-render`.** For every rendered client, `fixed_ip` equals
   `addressOn` for its host, and the client count equals the token count above.
   Control: a fixture host with an IPv4 and `mac = null` throws.
4. **Re-plan is clean (live, at build).** The first `unifi-plan` after
   `unifi-adopt` shows N to import (N = reservations already on the controller),
   then changes for exactly the declared fields that differ. A second plan after
   apply shows `0 to add, 0 to change, 0 to destroy`. Control: the first plan is
   non-empty, so the clean second plan is not an empty render's.
5. **Addresses on hosts (live, read-only).** `ip -6 addr` on each host shows
   `<prefix>:<s>:<token>/64` and `<ULA>:<token>/64`, and no DHCPv6 `/128`.
   Control: today's measurement (§1) has no token address on any host, so the
   predicate is shown to tell the two states apart.

## 4. What stage 2 needs from this plan (constraints only)

- The per-environment LB slice is P=1 (`…b601`, `…b611`). LB IIDs are
  zero-headed and never tokens. The gateway must route that /64 to the cluster's
  BGP next hops. Whether UniFi routes a PD-derived /64 that no LAN carries is
  unverified.
- Firewall policy is per environment /60, written as subnet id plus IID, because
  the prefix can change. If UniFi policies cannot express that, they are
  re-rendered from the live prefix on every apply.
- AAAA records hold prefix-dependent addresses, so their publication tracks the
  live prefix. Internal names can use the ULA, which does not move.

## 5. Risks

- **Prefix rotation** renumbers every GUA at once. Tokens keep the IIDs, and
  stage 1 publishes no GUA anywhere, but long-lived connections drop. Its
  frequency is not logged (§6 Q1).
- **dev renumber** (01 → 10) changes cortex, cortex-cuda and bitstream's GUAs
  once. Anything outside den that pinned one breaks. None was found in den.
- **Axons regain SLAAC.** The Cilium masquerade source changes from
  `::67f`-style leases to the token once, at deploy.
- **Duplicate `fixed_ip` during a NIC swap** may be refused by the controller.
  The apply order is then clear-then-set, in two applies.
- **Managed `name`** overwrites a name set by hand in the UI. This is intended,
  and the first plan shows each overwrite.
- **The cluster's ULA move** renumbers pod and service IPv6 and the fabric
  loopbacks. It is the last stage-1 commit, held until the owner deploys it.

## 6. Decisions (owner, 2026-11-11)

1. **Prefix stability: not logged.** The proposal to log the delegated prefix is
   rejected. The rule stands that den never stores the delegated prefix.
2. **The nibble convention: environment high.** Each environment owns a /60. The
   nibble is declared per environment (`ipv6Nibble`: prod 0, dev 1), not derived
   from its id. dev renumbers from `01` to `10`, and `Default` is pinned to `0`
   (§2.1).
3. **DHCPv6: den hosts drop it.** Their LAN links set `DHCPv6Client = false` and
   use SLAAC plus the token. `Default` keeps serving DHCPv6 to ordinary clients
   (§2.2).
4. **ULA reach: yes, in stage 1.** Hosts carry token ULAs. The cluster's
   `fdfd:cafe::/48` moves into the site /48 under P=2, per environment (§2.1).
   The IPv6 config is provisional and no pod depends on IPv6, so its addresses
   can be reassigned.
