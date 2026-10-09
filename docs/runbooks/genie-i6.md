# Runbook: make ninfer's exposure explicit (genie I6)

ninfer serves on **cortex-cuda** (`10.9.2.2:8081`), the microVM guest of
**cortex**, bridged onto the dev LAN (`10.9.0.0/16`). This change does two
things:

- **cortex-cuda's nftables** admit 8081 only from the hosts that consume
  `ninfer-endpoints` (pi, hermes, opencode; today blade, slab, patch, bitstream
  and cortex) and from the axon cluster's nodes. A consumer with a den address
  is admitted by that address. A consumer with none (blade, slab, patch) is
  admitted by its environment's network, `10.9.0.0/16`. The port leaves
  `allowedTCPPorts`.
- **The UniFi gateway** gets a legacy firewall rule (the gateway runs no
  zone-based firewall), `unifi_firewall_rule.ninfer_to_cortex_cuda_from_prod`:
  LAN_IN, accept tcp from the address group
  `unifi_firewall_group.ninfer_to_cortex_cuda_from_prod` (`10.10.10.2`,
  `10.10.10.3`, `10.10.10.4`, axon-01..03) to `10.9.2.2:8081`, rule index
  `20501`. No static route is declared. cortex-cuda has been on the dev LAN
  since cortex's `br0` bridge, so the hand-made route "Expose cortex-cuda"
  (`10.9.2.0/24` via `10.9.2.1`, id `6a961c1ba90d308b97c0068b`) is stale and is
  deleted in step 3.

Port **8080** (llama-cpp on cortex-cuda, which hindsight reaches from the
cluster) is unchanged and still open to every source. It is out of scope here.

Do the steps in order. Each one is verified before the next.

## 0. Pre-checks

From the nix-config checkout at the landed revision, with the devshell:

```bash
nix build .#checks.x86_64-linux.ninfer-firewall \
          .#checks.x86_64-linux.ninfer-gateway-policy \
          .#checks.x86_64-linux.unifi-gateway-policy-render --no-link
```

All three build (exit 0).

Record today's reachability. It is the baseline for every probe below:

```bash
probe() { curl -sS -m5 -o /dev/null -w '%{http_code}\n' http://10.9.2.2:8081/v1/models; echo "exit $?"; }
ssh axon-01 "$(typeset -f probe); probe"     # expect 200
ssh uplink  "$(typeset -f probe); probe"     # prod, not axon: note the result
probe                                        # from this workstation: note the result
ssh root@10.9.2.2 systemctl is-active ninfer # expect active
```

Check and note, read-only:

1. **Settings → Security → Traffic & Firewall Rules → LAN In** (or
   `GET /proxy/network/api/s/default/rest/firewallrule`). The existing rule
   "Prod to Dev access" (LAN_IN, accept, all protocols, network `Default` →
   network `dev`) stays: hindsight reaches llama-cpp on `10.9.2.2:8080` through
   it. Note its `rule_index`, and confirm that no rule already holds index
   `20501`. If one does, change `ruleIndexBase` in
   `modules/flake-parts/terranix/unifi.nix` and re-run the checks.
2. **Settings → Profiles → IP Groups** (`rest/firewallgroup`). Confirm that no
   group is already named `ninfer-to-cortex-cuda from prod`.
3. **Settings → Routing → Static Routes.** "Expose cortex-cuda", `10.9.2.0/24`
   via `10.9.2.1`. Note its distance; you need it for the rollback in step 3.

Zone-based policies do not apply: the controller reports
`zone-based-firewall-not-configured`.

## 1. Gateway: the prod→dev policy

You need the YubiKey.

```bash
unifi-plan
```

Expected: two creates,
`unifi_firewall_group.ninfer_to_cortex_cuda_from_prod will be created` and
`unifi_firewall_rule.ninfer_to_cortex_cuda_from_prod will be created`, then
`Plan: 2 to add, 0 to change, 0 to destroy.` Nothing else changes.

While "Prod to Dev access" exists, the new rule is redundant on the wire: the
broad rule already accepts everything from prod to dev. The new rule is the
declared path that remains once the broad rule is narrowed. Do **not** narrow,
delete or import "Prod to Dev access" yet. That cuts the cluster's path to 8080,
so it waits until 8080 has its own declaration.

Apply, then commit the encrypted state:

```bash
unifi-apply      # answer yes
git commit -m "unifi: state after the ninfer gateway policy" -- infra/unifi/terraform.tfstate
unifi-plan       # expect: No changes.
```

Verify: LAN In lists `ninfer-to-cortex-cuda from prod` at index 20501, and the
IP group lists the three axon addresses, and
`ssh axon-01 "$(typeset -f probe); probe"` still gives 200.

**Rollback.** Revert the landing's commits, or set
`settings.services.ai.ninfer.clients = null` on cortex-cuda, then run
`unifi-plan` (expect `2 to destroy`), `unifi-apply`, and commit the state.

## 2. Host: cortex-cuda's nftables

The guest is delivered by cortex. A deploy repoints the guest's runner but does
**not** restart the guest.

```bash
colmena apply --on cortex
ssh cortex 'readlink -f /var/lib/microvms/cortex-cuda/current; readlink -f /var/lib/microvms/cortex-cuda/booted'
# they differ: the new config is not live yet
ssh cortex sudo systemctl restart microvm@cortex-cuda   # ninfer is down until the guest is back
ssh cortex 'readlink -f /var/lib/microvms/cortex-cuda/current; readlink -f /var/lib/microvms/cortex-cuda/booted'
# now identical
```

Verify the ruleset on the guest:

```bash
ssh root@10.9.2.2 nft list chain inet nixos-fw input-allow | grep 8081
```

Expected: exactly these six rules.

```
ip saddr 10.10.10.2 tcp dport 8081 accept comment "ninfer: axon-01"
ip saddr 10.10.10.3 tcp dport 8081 accept comment "ninfer: axon-02"
ip saddr 10.10.10.4 tcp dport 8081 accept comment "ninfer: axon-03"
ip saddr 10.9.0.0/16 tcp dport 8081 accept comment "ninfer: blade patch slab"
ip saddr 10.9.1.1 tcp dport 8081 accept comment "ninfer: bitstream"
ip saddr 10.9.2.1 tcp dport 8081 accept comment "ninfer: cortex"
```

There is no bare `tcp dport 8081 accept`.

Live probes, with `probe` as defined in step 0:

| from                                                                                                                                                                | expected                                                                                                               |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `ssh axon-01` (and axon-02, axon-03)                                                                                                                                | `200`                                                                                                                  |
| a pod on axon: `kubectl run probe --rm -it --restart=Never --image=curlimages/curl -- curl -sS -m5 -o /dev/null -w '%{http_code}\n' http://10.9.2.2:8081/v1/models` | `200` (masqueraded to its node)                                                                                        |
| `ssh cortex`                                                                                                                                                        | `200`                                                                                                                  |
| `ssh bitstream`                                                                                                                                                     | `200`                                                                                                                  |
| blade (on the LAN)                                                                                                                                                  | `200`                                                                                                                  |
| `ssh uplink` (prod, not axon)                                                                                                                                       | `000`, `exit 28`: a timeout. The guest drops the packet rather than rejecting it, so there is no "connection refused". |

SSH (22) to the guest is unchanged: `ssh root@10.9.2.2 true`.

**Rollback.** For immediate relief, which lasts until the next firewall reload:

```bash
ssh root@10.9.2.2 nft insert rule inet nixos-fw input-allow tcp dport 8081 accept
```

For a durable rollback, revert the landing (or set `clients = null`), run
`colmena apply --on cortex`, and restart `microvm@cortex-cuda` as above.

## 3. Delete the stale static route

Delete "Expose cortex-cuda" (`10.9.2.0/24` via `10.9.2.1`, id
`6a961c1ba90d308b97c0068b`) in **Settings → Routing → Static Routes**.

Verify from axon-01:

```bash
ssh axon-01 traceroute -n -T -p 8081 10.9.2.2   # gateway (10.10.0.1), then 10.9.2.2; no 10.9.2.1 hop
ssh axon-01 "$(typeset -f probe); probe"         # 200
```

**Rollback.** Recreate the route with the next hop, distance and name from step
0.3.

## Notes

- **Narrowing the dev side later (arm iii).** Give blade, slab and patch den
  addresses (a static `ipv4` in `networking.interfaces`). Their entry in the
  guest's rule then becomes those addresses instead of `10.9.0.0/16`, with no
  other change. Update the six expected lines in
  `modules/den/aspects/services/ai/ninfer-firewall-check.nix` in the same
  landing.
- **A new consumer** (a host including pi, hermes or opencode) is admitted by
  construction, through the `ninfer-clients` quirk. Extra non-consumer hosts go
  in `settings.services.ai.ninfer.clients.hosts`.
- **8080** (llama-cpp) is still open to all sources on the guest, and its
  cluster path is the hand-made "Prod to Dev access" rule.
