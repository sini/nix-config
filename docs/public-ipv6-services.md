# Public IPv6 for individual services (address plan stage 2)

Status: **draft v0.2** (2026-11-12). The owner answered §7 (see §8). Nothing
here is built. It builds on `docs/address-plan.md` v0.3, whose §2.1 gives the
slices and whose §4 lists this stage's constraints.

## 1. Summary

Let a chosen Kubernetes Service take a public IPv6 address from its
environment's LB slice (GUA `<delegated /56>:81::/64` for prod), reachable from
the internet on the ports it declares and on nothing else. It is opt-in per
Service. With no Service opted in, nothing changes.

The owner asked for this as an option, not a commitment ("I don't know that we
want to do this, but would like it to be an option"). The design keeps the
option cheap to hold: the routing and gateway pieces can land and sit unused.

## 2. Goals and non-goals

Goals:

- A Service opts in with one label, and gets an address in the slice.
- The gateway routes the slice to the cluster over BGP, and admits inbound
  traffic only to the opted-in addresses and ports.
- A prefix change from the ISP re-addresses every opted-in Service, its firewall
  rule and its AAAA record, with no hand step.
- den never stores the delegated prefix (address-plan §6 Q1).

Non-goals:

- **HTTP services already behind Cloudflare.** A proxied name is already
  reachable over IPv6: Cloudflare answers AAAA and carries the request to the
  gateway over IPv4. Stage 2 is for what the proxy cannot carry: SSH, Matrix
  federation on a raw port, game or VPN endpoints.
- Pod IPv6 or the cluster ULA move (address-plan commit 7, held separately).
- Public IPv6 for hosts. Host GUAs stay unpublished.
- The dev environment. Its slice (`…:91::/64`) is reserved; dev runs no cluster.

## 3. What was measured (2026-11-11)

- **The gateway** is a UDM (UniFi OS 6.0.17) running FRR. It has four eBGP
  sessions, all IPv4: uplink and axon-01..03. Only `address-family ipv4 unicast`
  is configured. den renders that file (`unifi.nix` `renderBgpConfig`).
- **The axons** peer through their host FRR (`services/bgp/cilium-bgp.nix`):
  Cilium speaks only to its node's FRR (AS 65010 → 65001), and the host FRR
  speaks to the gateway. Both hops are IPv4-only today.
- **The delegated /56.** The WAN requests a /56 (`dhcp6PDRequestSize`). LANs
  hold `b600` and `b601`. The gateway has **no route** for the rest of the /56,
  so a route learned over BGP for `b681::/64` would be the only match. Policy
  routing consults `main`, where FRR installs, before the WAN table. So at the
  routing layer, the slice can work.
- **The axons' link-locals are EUI-64** (axon-01: `fe80::5a47:caff:fe79:e8e2`
  from `58:47:ca:79:e8:e2`). den declares each NIC's MAC, so each link-local is
  computable. The gateway's link-local is already declared
  (`networks.default.gatewayIpV6`).
- **Unmeasured:** whether the UDM's firewall forwards inbound IPv6 to a /64 that
  no LAN carries, and what its zone policies can match on. The live test (§6)
  answers both.

## 4. Proposal

### 4.1 Address allocation

A second Cilium pool, `lb-pool-v6`, holds the slice. A Service opts in with the
label `json64.dev/public-ipv6: "true"`, `ipFamilyPolicy: PreferDualStack` and
`type: LoadBalancer`. Only labelled Services draw from the pool, the same way
the L2 `lan-pool` selects by label today. Each gets one address, which Cilium
picks.

The pool's block is prefix-dependent, and den cannot hold the prefix, so the
pool is written at runtime (§4.4).

### 4.2 BGP

**IPv6 sessions over link-local**, one per axon, beside the existing IPv4
sessions:

- gateway `renderBgpConfig`: `neighbor fe80::<axon EUI-64>%br0` per axon in the
  same peer group, with `address-family ipv6 unicast` activating them. The
  addresses come from the declared MACs and are prefix-independent.
- axon host FRR: a neighbor at the gateway's declared link-local on its LAN
  interface, IPv6 family only, exporting only routes inside the LB slice's
  `/64`. That filter is the guard against announcing a pod or ULA route to the
  edge.
- Cilium → host FRR: add the `ipv6 unicast` family to `cilium-bgp`, advertising
  the labelled Services only.

**Rejected: IPv6 over the existing IPv4 sessions (MP-BGP).** Its next hop would
be IPv4-mapped unless each axon set a global IPv6 next hop. That address is
prefix-dependent, so it would need the same runtime rewriting as §4.4.

### 4.3 The gateway firewall

An allow policy from the External zone to each opted-in address, on its declared
ports only. Everything else in the slice stays blocked. The gateway's default
already drops unsolicited inbound IPv6.

Whether a policy can name a /64 outside any network is open until the live test.
If it cannot, the fallback is one UniFi network for the slice, which would draw
a LAN-style /64 from the low half (address-plan v0.3 §2.1).

### 4.4 Following the prefix

Everything prefix-dependent (the pool's block, the firewall destinations and the
AAAA records) is derived from the live prefix, never from den. Two arms:

**(a) An in-cluster reconciler (recommended).** A small controller reads the /56
from a node's own SLAAC address on the prod LAN (mask to /56; the node's token
address already carries the live prefix). It then writes:

1. `lb-pool-v6`'s block;
2. each opted-in Service's AAAA record in Cloudflare, grey (not proxied);
3. the gateway's allow policies, through the controller API.

It acts only when the prefix differs from what it last wrote, and it logs each
change. den declares the intent: which Services opt in and with which ports. The
reconciler supplies only the prefix.

- Costs: a Cloudflare token and a UniFi API key in the cluster, each scoped as
  narrowly as the APIs allow. terranix stops owning those policies; they get a
  name prefix the unifi workspace ignores.

**(b) terranix reads the prefix at plan time.** The unifi and dns workspaces
read the WAN's delegated prefix from the controller as a data source, and render
the policies and AAAA records from it. The pool block still needs (a)'s writer,
or an operator, on every change.

- Costs: after each prefix change, public IPv6 is broken until someone runs both
  applies. The prefix would also reach the encrypted terraform state, which is
  arguably "storing" it.

(a) is the only arm that meets the third goal. (b) is cheaper if the prefix
never changes in practice (§7 Q1).

## 5. Rollout

1. Address-plan v0.3 implementation (its §7).
2. The live test (§6). If the gateway does not forward to the slice, stop and
   revise §4.3.
3. BGP IPv6 sessions and filters (§4.2), with no Service opted in: the gateway
   learns no route. Check: sessions Established, 0 prefixes received.
4. The reconciler and `lb-pool-v6` (§4.4).
5. A first Service opted in, chosen by the owner.

Each step is reversible on its own: removing a step's code withdraws its routes
or policies.

## 6. Validation

**Live test (owner-approved 2026-11-11).** A hand-made route on axon-01: a
`/128` from the slice on its loopback, announced from its host FRR over a
temporary IPv6 session. Then, from an external IPv6 vantage point, ping it and
connect to one port. Then remove it. Answers:

- whether the gateway installs the learned route;
- whether its firewall forwards to the slice, with no rule and with an allow
  policy;
- whether a policy can name an address outside any network.

The external vantage still has to be chosen (§7 Q3).

**Build-time checks, following the `unifi-*-render` pattern:**

- `public-ipv6-bgp-render`: the gateway renders one IPv6 neighbor per axon at
  its EUI-64 link-local. Control: a fixture node with `mac = null` throws.
- `public-ipv6-export-filter`: the host FRR's IPv6 export accepts the slice and
  refuses the cluster ULA. Control: a fixture route in `fd3d:f136:2e4e:2::/64`
  is refused.

## 7. Open questions

1. **Is the delegated /56 static in practice?** Sonic (`2001:5a8::/32`) may
   assign a fixed prefix per account. If it does, arm (b) is enough, and the
   reconciler can wait until a change is ever seen. Unverified: the gateway logs
   no prefix history.
2. **Which arm for §4.4:** (a) reconciler, or (b) plan-time read?
3. **External vantage for the live test:** a phone on cellular IPv6, a public
   probe service, or a cloud VM?
4. **First Service to opt in**, if any.

## 8. Owner answers (2026-11-12)

1. **The /56 is not promised to be static.** So the prefix is followed at
   runtime, and arm (b) is out.
2. **§4.4: arm (a), the in-cluster reconciler.** It is a CronJob of roughly
   150–250 lines that reads the /56 from a node's own SLAAC address and writes
   the pool block, the AAAA records and the gateway policies. It carries a
   Cloudflare token scoped to the json64.dev zone's DNS edit, and a UniFi API
   key.
3. **Vantage:** the owner's phone on cellular for the first live test. An
   external VM is proposed separately (`docs/external-vantage-vm.md`) as the
   repeatable vantage.
4. **First Service: envoy-gateway**, today reached through UniFi's IPv4 port
   forward. A public IPv6 address for it serves the names Cloudflare does not
   proxy (`s3`, `hs`, `jellyfin`) to IPv6 clients directly. Proxied names
   already have IPv6 through Cloudflare.

Next: build the address-plan v0.3 steps, then run the live test (§6), then build
§5's steps 3–5 in order.
