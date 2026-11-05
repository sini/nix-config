# Hindsight: hosted Artemis access preparation

This is the credential foundation for hosted Artemis access to `den-law`, not a
working hosted connector. No public route, OAuth client, tunnel, or xmsg change
is included here. The writer is **disabled by default**: the default
configuration creates no new secret requirement or active grant. Once enabled,
do not deploy until its encrypted token and regenerated manifests are in the
same reviewed change.

Design:
[Hosted Artemis access to den law](https://gist.github.com/sini/8eae0acffe268e6a07721169418d5cd0).
This PR implements the named-writer foundation only. The spec's secret
identifier was proposed; this implementation uses the existing
`write-token-<bank>-<name>` naming pattern shown below.

## Credential boundary

The existing Hindsight den aspect can declare a named writer, `artemis`, on
`den-law`, through the typed cluster setting `artemisWriter.enable`. The writer
can read and write that bank, including destructive bank operations. It has a
separate credential, so it can be revoked or rotated without changing the fleet
owner's key or Vic's reader key. The control plane's admin key is not reused.

- Age declaration: `hindsight-write-token-den-law-artemis`.
- Encrypted source:
  `.secrets/env/prod/hindsight/write-token-den-law-artemis.age`.
- SOPS group/key: `hindsight` / `write-token-den-law-artemis`.
- Dataplane Secret/key: `hindsight-write-tokens` / `den-law.write.artemis`.

The server refuses startup if a configured writer's token is missing or empty.
Tokens are loaded on startup, so a rotation or revocation must also roll the
Hindsight dataplane. Keep token values out of chat, logs, command arguments, and
committed plaintext. A later OAuth adapter should receive this credential only
server-side; the hosted client must never receive it.

A recognized Artemis writer credential is refused on every other bank, including
open banks, and sees only `den-law` in bank listings. The existing owner,
reader, and anonymous behavior is preserved. **The token alone is not a public
bank-isolation boundary:** omitting it still reaches existing open banks. Any
later hosted adapter must pin `den-law` itself and must not expose the raw API
or the multi-bank `/mcp/` route.

## Owner preparation

Run these from the PR checkout in the repository's normal devshell, with the
master identity available. First enable the declaration in
`modules/den/clusters/axon.nix`:

```nix
settings.kubernetes.services.ai.hindsight.artemisWriter.enable = true;
```

This enables both secret generation and the gate's writer grant. Keep the change
on the PR branch until generation and rendering finish. These commands are
documented for the owner; no credential has been generated as part of this
change.

```bash
nix develop
agenix generate
git add .secrets/env/prod/hindsight/write-token-den-law-artemis.age
agenix sops-rekey
nixidy-sync
```

`agenix generate` generates missing declared secrets, not just this one. Review
its planned/output paths and the resulting diff. The repository's devshell may
stage encrypted outputs automatically. `agenix sops-rekey` updates the cluster's
SOPS source; `nixidy-sync` renders the manifests and runs their secret
post-processing. `nixidy-sync --skip-secrets` is suitable for ordinary source
checks, but preserves the previous encrypted Secret and **does not add this new
key**.

Expected relevant encrypted outputs include
`.secrets/clusters/axon/sops/hindsight.enc.yaml` and
`generated/manifests/prod-axon/hindsight/SopsSecret-hindsight-write-tokens.yaml`.
Generated Deployment/ConfigMap changes must come from nixidy, never hand edits.
Review the complete diff, including the new `writers` field in the gate config
and the updated Python module in its ConfigMap.

## Checks before deployment

```bash
python3 modules/den/aspects/kubernetes/services/ai/hindsight-write-gate-unit.py
nix build .#checks.x86_64-linux.hindsight-write-gate
nix-flake-build axon-01
nix flake check
treefmt
```

The hermetic test exercises credential decisions against small upstream
interface stand-ins. It is not proof that upstream HTTP/MCP routes call the
validator. Run the extended route oracle separately against the pinned
`hindsight-api-slim==0.9.2` and a **throwaway** PostgreSQL database with
pgvector:

```bash
gate_dir=$(mktemp -d)
cp modules/den/aspects/kubernetes/services/ai/hindsight-write-gate.py \
  "$gate_dir/hindsight_write_gate.py"
# Set HINDSIGHT_API_DATABASE_URL to the disposable database, not production.
python3 modules/den/aspects/kubernetes/services/ai/hindsight-write-gate-oracle.py \
  "$gate_dir"
```

The oracle creates and deletes fixture banks. Never point it at production. Its
admission assertions check the absence of a gate refusal, not successful
completion of every backend operation; some fixture requests intentionally
exercise invalid business inputs. Live positive controls must separately prove
actual write success. It covers named-writer admission on the bank's read/write
routes and MCP tools, rejection on other banks (including open banks), filtered
bank listings, preservation of reader-only access, and startup refusal for
missing, empty, or malformed writer configuration.

## Remaining hosted-access gates

1. Prove the real hosted client's supported custom-MCP flow and permitted write
   behavior. Backend authority does not override the platform's tool limits.
   Write tools must retain truthful read/write/destructive annotations.
2. Prove OAuth discovery, client registration or pre-registration, PKCE,
   resource/audience validation, expiration, refresh, and revocation against the
   actual authorization server. Browser OIDC for the control plane is not an MCP
   authorization implementation. Do not assume Kanidm supports all required
   resource/audience behavior without testing it.
3. Implement the private bank-pinned adapter and tunnel with a dedicated OAuth
   resource, tokens, and identity. Reuse deployment/authentication patterns with
   xmsg only after its separate audience and backend authorization are
   preserved.
4. Inspect the live `den-law` MCP tool allowlist. The client aspect documents a
   prior read-only allowlist set manually on the bank. This PR neither reads nor
   changes that live state; a full token does not itself expose write tools.
5. Verify end-to-end positive and negative controls before enabling ingress.
   Neither this PR nor its preparation commands deploy or publish the endpoint.

## Revocation

Set `artemisWriter.enable = false`, regenerate manifests through nixidy and the
normal secret workflow, then deploy through the owner-approved process. Roll the
dataplane so it drops the in-memory writer credential. Existing owner, reader,
and control-plane credentials remain unchanged. A future hosted adapter also
needs its own access/refresh-token and session revocation.
