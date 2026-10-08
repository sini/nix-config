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
`unifi.bgp.config` in `modules/den/environments/prod.nix` holds the raw FRR
`bgpd` file, byte for byte as the controller stores it, together with the
controller's `description` and `uploadFileName`. It replaced the hand-uploaded
`generated/bgp/unifi-frr-bgp-{prod,dev}.conf` (deleted; their generator was
removed in `65c53a07`).

Next, the peers will be rendered from the BGP hosts' own records instead of the
raw file (`ingress-native-design.md` §13.3). Port forwards come after that.

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
`X-Api-Key`) and the passphrase into its own environment, and prints neither.

1. `unifi-adopt` reads the site's BGP configuration with a single `GET`. It then
   writes `infra/unifi/imports.tf.json`, which imports `unifi_bgp.prod` by its
   site name.
2. `unifi-plan` builds the config and runs `tofu init` and `tofu plan`. The
   adoption plan must be `1 to import, 0 to add, 0 to change, 0 to destroy`. A
   change means the live config differs from the declared one. Read it before
   applying.
3. `unifi-apply` runs the same steps, then `tofu apply`, which asks for
   confirmation. Applying the import changes nothing on the gateway.
4. Commit `infra/unifi/terraform.tfstate`, which is encrypted.
