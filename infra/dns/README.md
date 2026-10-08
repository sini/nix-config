# Public DNS (Cloudflare, OpenTofu)

Public DNS records for every managed zone, declared in Nix with
[terranix](https://terranix.org) and applied with OpenTofu, in one workspace
with one state. The code lives in `modules/flake-parts/terranix/`:
`terranix.nix` wires it in, and `dns.nix` holds the records module.

## What is managed

Zones are den domain entities (`den.domains.<fqdn>`, `modules/den/domains/`),
composed from the aspects in `modules/den/aspects/domain/domain.nix`. A domain
with `dns.cloudflare <account>` is a managed Cloudflare zone; the prod list is
`json64.dev`, `gen.wtf` and the seven landing zones. A domain without it is
either hosted in its nearest managed ancestor (`dev.json64.dev` and
`s3.json64.dev` in `json64.dev`) or, with no managed ancestor, not managed at
all (`zeroday.run`, certificates only).

The records come from two places, and each record lands in the longest managed
zone that contains it, from whichever environment produced it:

- **The domains' own records** (`dns-records`): `web.apex` (the apex and `www.`,
  proxied, for `json64.dev` and every `web.landing` zone), `pages.github` (the
  `gen.wtf` GitHub Pages A/AAAA records, the `www` CNAME and the Pages challenge
  TXT), `mail.protonmail` (the `json64.dev` MX, SPF, verification, DKIM and
  DMARC records) and `dns.records` (`hs` and `jellyfin`, grey CNAMEs to the apex
  as live; `vpn`; `*.s3.json64.dev` for S3 vhost-style buckets). A null content
  is the edge's public IPv4.
- **Served names** (`served-domains`): an `A` record to the serving
  environment's `dns.publicIPv4` (prod: `157.131.140.225`) for every name a host
  (nginx vhosts) or a cluster (gateway routes) emits through
  `environment.servedDomains` / `cluster.servedDomains`. A name the zone
  declares itself is not derived again. An environment with no `dns.publicIPv4`
  publishes no records (dev). A service whose aspect is not enabled on any host
  or cluster gets no record; Tdarr is one, since it is commented out in
  `clusters/axon.nix`.

Every record has `ttl = 1` (auto). A resource key is the name, the type and a
short hash of the content, so several records can share a name (the `gen.wtf`
apex, the `json64.dev` MX and TXT) and reordering never replaces one.

To see the generated set:

```sh
nix build .#dns.config && jq '.resource.cloudflare_dns_record' result
```

**Grey cloud.** A served name is proxied unless its producer says otherwise:
`matrix.json64.dev` (synapse), `matrix.gen.wtf` (tuwunel) and `s3.json64.dev`
(garage s3) emit `served-domains` with `proxied = false`. Matrix federation does
not work through the Cloudflare proxy, and its 100 MB upload cap breaks S3
multipart. A domain's own records are grey unless they set `proxied = true`.

**Not managed.** OpenTofu touches only the records it declares. Every other
record in these zones is left alone and never read into state, including CAA and
the ACME `_acme-challenge` records. This also holds for every zone without
`dns.cloudflare`.

## State

The state is `infra/dns/terraform.tfstate` (local backend). It is committed to
git, encrypted with OpenTofu's native state encryption: a `pbkdf2` key derived
from `TF_VAR_state_passphrase`, using `aes_gcm`, enforced for both state and
plan files. A wrong passphrase fails to decrypt instead of starting from an
empty state.

The passphrase is the agenix secret `tofu-state-passphrase`
(`.secrets/env/prod/tofu-state-passphrase.age`, generator `rfc3986-secret`). It
is declared as an intermediary secret on `uplink`, so `agenix generate` creates
it encrypted to the master identities only, and it is never rekeyed to a host.

## Operator flow

You need the YubiKey. Each command decrypts the Cloudflare token of the zones'
account (`cloudflareTokens` in `terranix.nix`) and the passphrase into its own
environment, and prints neither.

1. `dns-adopt` lists the live records of each managed zone (a read-only `GET`)
   and reads the state. It matches live records to the declared set by name,
   type and **content**, since several records share a name, then writes
   `infra/dns/imports.tf.json`: an `import` block per matched record that is not
   in state, and a `moved` block per matched record that is in state under
   another address (a key change). It warns when a declared name is held by a
   CNAME of a different type, or the reverse. Fix those by hand first, because a
   CNAME cannot share its name.
2. `dns-plan` builds the config and runs `tofu init` and `tofu plan`. Expect
   imports and moves with **no change** for the adopted records and **creates**
   only for the missing ones. If an adopted record shows an update, its live
   content, proxy status or priority differs from the declaration. Read it
   before applying.
3. `dns-apply` runs the same steps, then `tofu apply`, which asks for
   confirmation.
4. Commit `infra/dns/terraform.tfstate`, which is encrypted. Once the records
   are in state at their addresses, the import and moved blocks are no-ops, so
   `imports.tf.json` can be deleted or kept as a record of what was adopted.

The Cloudflare token needs `Zone:Read` and `DNS:Edit` on every managed zone.
`dns-adopt` stops if a zone is not visible to it.
