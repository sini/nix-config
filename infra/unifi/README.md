# UniFi gateway (OpenTofu)

The UniFi gateway's configuration, declared in Nix with
[terranix](https://terranix.org) and applied with OpenTofu through the
`ubiquiti-community/unifi` provider (0.56.1, from nixpkgs). The workspace is
`modules/flake-parts/terranix/unifi.nix`. It is a separate workspace and state
from DNS (`infra/dns`).

## The controller

The controller is the gateway itself, at `https://<networks.default.gatewayIp>`,
and the provider talks to UniFi site `default`. Prod reaches it as `10.10.0.1`
and dev as `10.9.0.1`. Both addresses are the same device and the same site,
which is the only site on it. Exactly one environment may therefore set `unifi`,
and prod does. If dev set it too, both states would own the same objects.

## What is managed

`unifi_bgp.prod` is the gateway's BGP configuration, a single object per site.
Its raw FRR `bgpd` file is rendered by `modules/flake-parts/terranix/unifi.nix`
from the environment's `bgp-peers` records (one per BGP host, routed by
`env-collect-bgp-peers`): AS `networks.default.gatewayAsn`, router-id
`networks.default.gatewayIp`, one peer group per remote AS, and each neighbor's
AS from its own record. The hub (`services.bgp.hub`) and the axon hosts
(`services.bgp.cilium-bgp`, `peerWithGateway`) peer back with the same two
values. The provider's structured `peers` mode is not used: its template forces
`bgp ebgp-requires-policy`, `redistribute connected`, `next-hop-self`, multihop
and timers, and cannot set `maximum-paths`. `unifi.bgp` in
`modules/den/environments/prod.nix` keeps the controller's `description` and
`uploadFileName`.

`unifi_port_forward.<name>` is one per port forward on the gateway. Each is
declared by the aspect that owns the public port, as a `port-forwards` record
(`{ environment; name; protocol; wanPort; forward = { ip; port; }; allWans ? false; }`),
routed to the environment by `env-collect-port-forwards` (host and cluster
records of that environment) and rendered by `renderPortForwards`:

| resource              | declared by                                                                                                                       |
| --------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `headscale_to_uplink` | `services.networking.headscale`, per host: `headscale-to-<host>`, UDP 3478 (STUN) and 41641 to the host's default-network address |
| `ssh_to_uplink`       | `core.security.openssh`, per host with `exposure = "public"`: `ssh-to-<host>`, TCP 22                                             |

The resource name is the forward's name, lowercased, with each run of other
characters as `_`, the same key `unifi-adopt` derives from a live forward's
controller name. A forward's wan side is the first of `unifi.wans` (prod: `wan`,
`wan2`), and an `allWans` forward listens on each of them (the controller's
`destination_ips`). Two forwards with the same resource name, or overlapping WAN
ports on overlapping protocols, fail the evaluation
(`checks.<system>.unifi-port-forward-render`). A change to a forward is an edit
of its aspect, reviewed in `unifi-plan`.

A record with `mode = "nat"` (envoy-gateway's `<cluster>-https-ingress`, 443 TCP
and UDP to the cluster's `default-gateway` assignment) is rendered by
`renderNat` as the gateway's custom NAT rules (v2 `nat`,
`restapi_object.<name>_*`, through the `Mastercard/restapi` provider, packaged
in `unifi.nix`) instead of a port forward. A port forward to a target off the
gateway's own networks (the cluster VIPs) masquerades every client, so the
target sees the gateway's address. The nat rules masquerade hairpin clients
only:

| rule                | match                                                         | action                    |
| ------------------- | ------------------------------------------------------------- | ------------------------- |
| `<name>_dnat_wan`   | in on `unifi.networks.wan`, to `dns.publicIPv4`:wanPort       | DNAT to forward           |
| `<name>_dnat_<lan>` | in on each of `unifi.networks.lans`, to the same              | DNAT to forward (hairpin) |
| `<name>_masq_<lan>` | from each LAN (`NETWORK_CONF`), to forward, out the first LAN | MASQUERADE                |

The controller requires a DNAT's inbound and a masquerade's outbound interface,
as networkconf ids, so the rules look them up by the controller's network names
(`unifi.networks`, `data.restapi_object.unifi_network_*`). A wrong name fails
the plan before anything is written. `axon-https-ingress` is nat;
`checks.<system>.unifi-nat-render` fixes the payloads.

## State

The state is `infra/unifi/terraform.tfstate` (local backend). It is encrypted
with OpenTofu's native state encryption: a `pbkdf2` key derived from
`TF_VAR_state_passphrase`, using `aes_gcm`, enforced for both state and plan
files. The passphrase is the agenix secret `unifi-state-passphrase`
(`.secrets/env/prod/unifi-state-passphrase.age`, generator `rfc3986-secret`). It
is declared as an intermediary secret on `uplink`, so it is encrypted to the
master identities only and never rekeyed to a host.

## Operator flow

You need the YubiKey. Each command decrypts the API key
(`.secrets/env/prod/unifi-api-key.age`, a UniFi Integrations key sent as
`X-Api-Key` by both providers, to the restapi one as `TF_VAR_unifi_api_key`) and
the passphrase into its own environment, and prints neither.

1. `unifi-adopt` reads the site's BGP configuration and its port forwards
   (`rest/portforward`), with `GET`s only. It only imports: it writes
   `infra/unifi/imports.tf.json`, which imports `unifi_bgp.prod` by its site
   name and each live port forward by its `_id`, and stages it (the flake reads
   only tracked files). It writes no configuration, so a live forward that no
   aspect declares fails the plan until it is declared or deleted. It prints the
   live forward list.
2. `unifi-plan` builds the config and runs `tofu init` and `tofu plan`. The
   adoption plan must be `N to import, 0 to add, 0 to change, 0 to destroy`, N
   being the port forwards (`unifi_bgp.prod` is already in the state). A change
   means the live config differs from the declared one. Read it before applying.
3. `unifi-apply` runs the same steps, then `tofu apply`, which asks for
   confirmation. Applying the import changes nothing on the gateway.
4. Commit `infra/unifi/terraform.tfstate`, which is encrypted.
