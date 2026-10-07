# Public DNS (Cloudflare, OpenTofu)

The prod environment's public DNS records, declared in Nix with
[terranix](https://terranix.org) and applied with OpenTofu. The code lives in
`modules/flake-parts/terranix/`: `terranix.nix` wires it in, and `dns.nix` holds
the records module.

## What is managed

A derived record is an `A` record pointing at `dns.publicIPv4` (prod:
`157.131.140.225`), with `ttl = 1` (auto). It is proxied (orange cloud) unless
its hostname is listed in `dns.unproxied`. The derived records are:

- the apex and `www.` of every `certificates.domains` entry with `apex = true`
  (the `www.` names 301 to the apex, `garage/sites.nix`);
- every name in a prod `served-domains` record. Host aspects (nginx vhosts) and
  cluster aspects (gateway routes) emit these records through
  `environment.servedDomains` / `cluster.servedDomains`, which resolve names via
  `getDomainFor`, so a `services.<name>.domain` override applies. The
  environment collects them from both kinds of scope. The record's internal
  `address` is not used here.

`dns.records.<hostname> = { type; content; proxied; }` is laid over that set. It
overrides a derived name, or adds one the derivation cannot produce. Prod uses
it for `hs.json64.dev` and `jellyfin.json64.dev`, which are grey `CNAME`s to
`json64.dev` as they are live, and for `*.s3.json64.dev` (S3 vhost-style
buckets). `type` is `A` or `CNAME`, a null `content` means `dns.publicIPv4`, and
a null `proxied` means the `dns.unproxied` rule.

A record is kept only if its zone is in `dns.managedZones`. The prod list is the
apex zones plus `gen.wtf`. So `argocd.zeroday.run` is not managed, because
`zeroday.run` is not a managed zone. A service whose aspect is not enabled on
any prod host or cluster gets no record. Tdarr is one, since it is commented out
in `clusters/axon.nix`.

To see the generated set:

```sh
nix build .#dns.config && jq '.resource.cloudflare_dns_record' result
```

**Grey cloud** (`dns.unproxied` in `modules/den/environments/prod.nix`):
`matrix.json64.dev`, `matrix.gen.wtf`, `s3.json64.dev` and `*.s3.json64.dev`.
Matrix federation does not work through the Cloudflare proxy, and its 100 MB
upload cap breaks S3 multipart. `hs` and `jellyfin` are grey too, through their
`dns.records` entries.

**Not managed.** OpenTofu touches only the records it declares. Every other
record in these zones is left alone and never read into state, including MX,
TXT, CAA, the ACME `_acme-challenge` records, the `*.json64.dev` wildcard and
the `gen.wtf` apex (GitHub Pages). This also holds for every zone outside
`dns.managedZones`.

## The `*.json64.dev` wildcard

A proxied `*.json64.dev` record is live and is deliberately **not** managed yet.
Until it goes, any `json64.dev` name resolves whether or not it is declared, so
DNS is wider than the declared set. To close that gap:

1. After the first `dns-adopt`, every declared `json64.dev` name with no import
   block existed only through the wildcard. `dns-apply` creates those names as
   explicit records.
2. Any other name served through the wildcard that should stay public gets
   declared, as a `served-domains` emission or a `dns.records` entry.
3. Delete the wildcard record in Cloudflare. DNS then equals the declared set.

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

You need the YubiKey. Each command decrypts the Cloudflare token
(`.secrets/env/prod/cloudflare-api-key.age`) and the passphrase into its own
environment, and prints neither.

1. `dns-adopt` lists the live records of each managed zone (a read-only `GET`).
   It matches them to the declared set by name and type, then writes
   `infra/dns/imports.tf.json`, with one `import` block per record that already
   exists. It warns when a declared name exists with a different type, such as a
   `www` CNAME. Fix those by hand first, because OpenTofu cannot create an `A`
   record beside a CNAME.
2. `dns-plan` builds the config and runs `tofu init` and `tofu plan`. Expect
   imports with **no change** for the adopted records and **creates** only for
   the missing ones. If an adopted record shows an update, its live content or
   proxy status differs from the declaration. Read it before applying.
3. `dns-apply` runs the same steps, then `tofu apply`, which asks for
   confirmation.
4. Commit `infra/dns/terraform.tfstate`, which is encrypted. Once the records
   are in state, the import blocks are no-ops, so `imports.tf.json` can be
   deleted or kept as a record of what was adopted.

The Cloudflare token needs `Zone:Read` and `DNS:Edit` on every managed zone.
`dns-adopt` stops if a zone is not visible to it.
