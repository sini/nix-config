# xmsg-gateway: authorization-server cutover, step 3 (owner maintenance window)

The procedure for step 3 of xmsg-design
`specs/gateway/gateway-authorization-server.md` §2.10: serve both profiles,
Kanidm hidden (`advertised: false`) and the gateway's own authorization server
as `opaque_default`, with Events still on the OLD grant `chatgpt`. Steps 4
onward (drain, `cutover-events`, the new Events grant) are separate.

Names: the hosted client is `xmsg-chatgpt`, the local grant `chatgpt-as`, and
the new connector's redirect is
`https://chatgpt.com/connector/oauth/44LD9UTXVNyp` (`clusters/axon.nix`,
`authorizationServer.redirectUris`). Setting that option is what turns the
authorization server on in `kubernetes/services/ai/xmsg-gateway.nix`.

## Before the window

1. **SOPS.** The gateway's Secret gains `as-client-secret` and `liveness-token`.
   With the master YubiKey, run `agenix sops-rekey` and commit
   `.secrets/clusters/axon/sops/xmsg-gateway.enc.yaml`. Without it the pod's
   `prepare` step fails on the missing files.
2. **Owner sentinels.** Deploy uplink (the kanidm writer), so
   `kanidm-xmsg-gateway-liveness` plants the owner's `account_valid_from` and
   `account_expire`. It reads each first and writes only an unset one. On
   2026-11-18 both were unset ("valid after: any time", "expire: never"), so
   this deploy writes 2000-01-01T00:00:00Z and 2099-12-31T00:00:00Z. The
   liveness reader fails closed without them. Read back:
   `journalctl -u kanidm-xmsg-gateway-liveness`.

## The window

The real store must have `chatgpt-as` enrolled and enabled before the new
Deployment runs: its `store-local-apply` step fails on a missing grant, and
`enroll` is not idempotent. So the store work is a one-off Job, and the
Deployment syncs after it.

1. Pause Argo's auto-sync for `xmsg-gateway`, then
   `kubectl -n xmsg-gateway scale deploy/xmsg-gateway --replicas=0`. Wait until
   no pod remains.
2. Take an untouched backup: a Longhorn snapshot of PVC `xmsg-gateway`. The
   owner configuration's backup is the ConfigMap at the pre-cutover commit.
3. Apply the new ConfigMap alone (it adds `local-binding.json`), from the
   cutover commit's
   `generated/manifests/prod-axon/xmsg-gateway/ConfigMap-xmsg-gateway-config.yaml`.
4. Run the store Job with the pinned gateway image: the PVC at
   `/var/lib/xmsg-mcp-gateway`, the config ConfigMap at `/etc/xmsg-mcp-gateway`,
   uid and gid 10001, the Deployment's hardened securityContext. One container
   per command, in order, each
   `--state /var/lib/xmsg-mcp-gateway/state/grants.db`:
   - `migrate-profiles --if-needed`
   - `migrate-attachments --if-needed`
   - `migrate-authorization-server --if-needed`
   - `migrations-pending`: it must exit 0 with an empty list
   - `enroll chatgpt-as /etc/xmsg-mcp-gateway/local-binding.json`
   - `enable chatgpt-as 1`
5. Resume Argo and sync. The Deployment's init chain finds every migration done,
   applies the outbound policy to both grants, and serves.
6. Read back:
   - `/.well-known/oauth-protected-resource` lists only
     `https://xmsg-gateway.json64.dev`;
   - `/.well-known/oauth-authorization-server` answers 200 with that issuer;
   - `/mcp` without a token answers 401 with the PRM challenge;
   - the pod is Ready with 0 restarts, and OLD still works through the tunnel.

## Lesson from the window (2026-11-18)

The pod's `secrets` volume projects only the keys in its `items` list
(`kubernetes/services/ai/xmsg-gateway.nix`). A key added to the SopsSecret
reaches the Secret but not the pod until it is also listed there. The first
post-cutover pod failed `prepare` with
`cp: can't stat '/run/secrets/xmsg-gateway/as-client-secret'`, fixed in
4d274369. A new Secret key needs both the SopsSecret entry and an `items` entry.

## Rollback

- Before step 4 changes the store, revert the cutover commit and scale back up.
- Afterwards, schema rollback: with the pod stopped, restore the Longhorn
  snapshot and the pre-cutover configuration together, then check startup and
  OLD's identity. This discards the store's state after the snapshot.

## Follow-up

The liveness token is minted by `kanidm-xmsg-gateway-liveness` on the kanidm
writer (uplink today) and copied once into the agenix secret
`.secrets/env/prod/xmsg-gateway/liveness-token.age`. The gateway's copy doesn't
depend on uplink's state. The mint moves with the writer to axon-01
(`docs/uplink-maintenance-plan.md`). After that move, verify that the copied
token still authenticates, and re-copy it only if the new writer mints a new
one.
