# Runbook: cluster-wide DNS egress (`allow-kube-dns-cluster-egress`)

DNS reachability is owned by `services.network.coredns`
(`modules/den/aspects/kubernetes/services/network/coredns/coredns.nix`). Beside
its ingress half, `allow-kube-dns-cluster-ingress`, it now ships the egress
half:

| Object                                                         | Selects               | What it allows                                                   |
| -------------------------------------------------------------- | --------------------- | ---------------------------------------------------------------- |
| CiliumClusterwideNetworkPolicy `allow-kube-dns-cluster-egress` | every endpoint (`{}`) | egress to the CoreDNS pods on UDP/TCP 53, L4 only (no DNS proxy) |

It sets `enableDefaultDeny` false both ways, so it only adds an allow and never
puts an endpoint into egress enforcement.

The same change deletes 26 per-app DNS egress rules from source: 24 whole
`allow-*dns-egress*` policies (the media apps, synapse, tuwunel, smtp-relay,
garage) and the DNS entry of `allow-synapse-admins-egress` and argocd's
`allow-external-egress`. On prod-axon, 20 of the policies and both entries are
rendered. tdarr, configarr and recyclarr are not deployed there. Every one
selected `k8s-app: kube-dns`, which is only the CoreDNS Service's label: the
pods carry `k8s-app: coredns`. So they matched no pod and granted nothing. DNS
has worked only through the cluster-wide `allow-internal-egress` (app `cilium`).
Deleting them changes no datapath verdict. The new policy is what keeps DNS
allowed if `allow-internal-egress` is ever tightened.

`genie-eval` keeps its own L7 DNS rule, because its `toFQDNs` allowlist needs
the DNS proxy, and it stays excluded from `allow-internal-egress`. The new
policy gives it only what it already had: port 53 to CoreDNS.

Every command runs from the nix-config devshell with `kubectl` pointed at the
axon cluster (`export KUBECONFIG=$HOME/.config/kube/config`).

## 0. Pre-checks

The render gates must be green at the revision you merge:

```bash
nix build --no-link -L .#checks.x86_64-linux.dns-egress
nix build --no-link -L .#checks.x86_64-linux.genie-eval
```

Expected: `dns-egress: OK (<n> policies)` and exit 0 for both.

Baseline the drops before the merge so that a later drop can be attributed:

```bash
kubectl -n kube-system exec ds/cilium -c cilium-agent -- \
  hubble observe --verdict DROPPED --type policy-verdict --port 53 --last 50
```

## 1. Merge, then sync `coredns` first

The merge is the deploy, since every app tracks `main` with automated sync,
prune and self-heal. Sync `coredns` by hand straight after the merge, so that
the egress policy exists before the per-app policies are pruned:

```bash
argocd app sync coredns
kubectl get ciliumclusterwidenetworkpolicy allow-kube-dns-cluster-egress
```

Expected: the CCNP is listed. The other apps (the media apps, `synapse`,
`tuwunel`, `synapse-admins`, `smtp-relay`, `garage`, `argocd`) then sync on
their own and prune their `allow-*dns-egress*` policies. Because those policies
matched no pod, the order guards nothing on the datapath. It is kept anyway, so
that no window exists in which DNS rests on `allow-internal-egress` alone.

```bash
kubectl get cnp -A | grep -c dns-egress
```

Expected: `0`.

## 2. Watch for drops

Run this for a few minutes while the apps sync:

```bash
kubectl -n kube-system exec ds/cilium -c cilium-agent -- \
  hubble observe --verdict DROPPED --type policy-verdict --port 53 --follow
```

Expected: no new port-53 drops beyond the baseline. A drop from `genie-eval` to
anything other than CoreDNS is that namespace's own policy working, not a
regression.

## 3. Probe DNS from one media pod

```bash
kubectl -n media exec deploy/sonarr -- getent hosts kubernetes.default.svc.cluster.local
kubectl -n media exec deploy/sonarr -- getent hosts github.com
```

Expected: an address for both, the first in-cluster and the second resolved
upstream through CoreDNS.

## Rollback

Revert the merge commit on `main`. ArgoCD then restores the per-app policies,
which are inert, and prunes `allow-kube-dns-cluster-egress`. DNS keeps working
throughout on `allow-internal-egress`. For an emergency without a revert, delete
the CCNP by hand. Self-heal will recreate it, so disable automated sync on
`coredns` first:

```bash
argocd app set coredns --sync-policy none
kubectl delete ciliumclusterwidenetworkpolicy allow-kube-dns-cluster-egress
```
