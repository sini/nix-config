# Runbook: deploy the `genie-eval` namespace

`genie-eval` is where genie-agent runs its untrusted Nix evals, one Job per
eval. The aspect is `services.ai.genie-eval`
(`modules/den/aspects/kubernetes/services/ai/genie-eval.nix`), and it renders to
the ArgoCD app `genie-eval`:

| Object                                   | Namespace    | What it does                                                                 |
| ---------------------------------------- | ------------ | ---------------------------------------------------------------------------- |
| ServiceAccount `genie-eval-launcher`     | `matrix`     | the identity the genie-agent pod will run as                                 |
| Role + RoleBinding `genie-eval-launcher` | `genie-eval` | create/get/list/watch/delete `batch/jobs`; get/list/watch `pods`, `pods/log` |
| LimitRange `genie-eval`                  | `genie-eval` | per container: limit and max 12Gi / 2 CPU, default request 1Gi / 250m        |
| ResourceQuota `genie-eval`               | `genie-eval` | at most 4 pods                                                               |
| CiliumNetworkPolicy `genie-eval-egress`  | `genie-eval` | egress to kube-dns and, on 443, the six fetch hosts only; all ingress denied |

One change lands in another app: the cluster-wide policy `allow-internal-egress`
(app `cilium`, `network/cilium/cilium.nix`) no longer selects pods in
`genie-eval`. Cilium policies only add allows, so without this the eval pods
could still reach every pod in the cluster.

Nothing runs in `genie-eval` until genie-agent is deployed (unit I12), so the
namespace can be deployed and verified on its own.

Every command runs from the nix-config devshell with `kubectl` pointed at the
axon cluster (`export KUBECONFIG=$HOME/.config/kube/config`).

## 0. Pre-checks

The render gate must be green at the revision you merge:

```bash
nix build --no-link -L .#checks.x86_64-linux.genie-eval
```

Expected: `genie-eval: OK (6 objects)`, exit 0.

The cluster must have Cilium's L7 DNS proxy, which `toFQDNs` depends on. This is
the first `toFQDNs` policy in the repo:

```bash
kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status | grep -i proxy
```

Expected: a `Proxy Status: OK` line. If the proxy is disabled, stop: the egress
policy would allow DNS but no fetch host.

The namespace and the SA must not exist yet:

```bash
kubectl get ns genie-eval
kubectl -n matrix get sa genie-eval-launcher
```

Expected: `NotFound` for both.

## 1. Merge to `main`

Every app here tracks `main` with automated sync, prune and self-heal, so the
merge is the deploy. ArgoCD then syncs `apps` (creates the `genie-eval`
Application), `bootstrap` (creates the Namespace), `cilium` (the narrowed
`allow-internal-egress`) and `genie-eval`.

**Rollback:** revert the merge commit on `main`, then do the cleanup in step 5.

## 2. Sync `cilium` first

Apply the narrowed cluster-wide policy before the eval objects. Then the
namespace never exists with in-cluster egress open:

```bash
kubectl -n argocd annotate application cilium argocd.argoproj.io/refresh=hard --overwrite
kubectl -n argocd get application cilium -o jsonpath='{.status.sync.status} {.status.health.status}{"\n"}'
kubectl get ccnp allow-internal-egress -o jsonpath='{.spec.endpointSelector}{"\n"}'
```

Expected: `Synced Healthy`, and a selector with a `NotIn` on
`k8s:io.kubernetes.pod.namespace` with values `["genie-eval"]`.

Check that nothing else lost its in-cluster egress. The new selector still
covers every other namespace, and `NotIn` also covers endpoints without the
label (host, health). Watch for new egress drops outside `genie-eval` for a few
minutes:

```bash
kubectl -n kube-system exec ds/cilium -c cilium-agent -- hubble observe --verdict DROPPED --type policy-verdict --last 50
```

Expected: no drops that were not there before the sync. Spot-check one
in-cluster flow too, for example Synapse reaching `matrix-pg`
(`kubectl -n matrix logs deploy/synapse --since=5m | grep -i 'connection refused\|timeout'`
prints nothing). If anything regresses, roll back now.

**Rollback:** revert `network/cilium/cilium.nix`'s selector to
`endpointSelector = { };` and run `nixidy-sync`, commit and merge. Or patch it
live until the revert lands (self-heal will undo this patch once the revert is
merged):

```bash
kubectl patch ccnp allow-internal-egress --type merge -p '{"spec":{"endpointSelector":{"matchExpressions":null}}}'
```

## 3. Sync `genie-eval`

```bash
kubectl -n argocd annotate application genie-eval argocd.argoproj.io/refresh=hard --overwrite
kubectl -n argocd get application genie-eval -o jsonpath='{.status.sync.status} {.status.health.status}{"\n"}'
kubectl -n genie-eval get role,rolebinding,limitrange,resourcequota,cnp
kubectl -n matrix get sa genie-eval-launcher
```

Expected: `Synced Healthy`. The listing shows the Role, RoleBinding, LimitRange,
ResourceQuota (`pods: 0/4`) and CNP, all named as in the table above, and the SA
exists in `matrix`.

Confirm the agents accepted the policy (a policy can pass the apiserver and
still be refused by the agent; see `media/network-policy.nix`):

```bash
kubectl -n genie-eval get cnp genie-eval-egress -o jsonpath='{.status}{"\n"}'
```

Expected: no `error` field in any node's status.

**Rollback:** step 5.

## 4. Live verification

### RBAC

```bash
SA=system:serviceaccount:matrix:genie-eval-launcher
kubectl auth can-i --as=$SA create jobs -n genie-eval      # yes
kubectl auth can-i --as=$SA delete jobs -n genie-eval      # yes
kubectl auth can-i --as=$SA get pods/log -n genie-eval     # yes
kubectl auth can-i --as=$SA patch jobs -n genie-eval       # no
kubectl auth can-i --as=$SA create pods -n genie-eval      # no
kubectl auth can-i --as=$SA get secrets -n genie-eval      # no
kubectl auth can-i --as=$SA create jobs -n matrix          # no
kubectl auth can-i --as=$SA get secrets -n matrix          # no
```

Each line should print the result in its comment. Any other output is a failure:
roll back with step 5.

### Bounds

Server-side dry run shows what admission applies, without creating a pod:

```bash
kubectl -n genie-eval run bounds-probe --dry-run=server --image=busybox -o jsonpath='{.spec.containers[0].resources}{"\n"}'
```

Expected: limits `{"cpu":"2","memory":"12Gi"}`, requests
`{"cpu":"250m","memory":"1Gi"}`. A pod that asks for more than the max is
refused:

```bash
kubectl -n genie-eval run too-big --dry-run=server --image=busybox --overrides='{"spec":{"containers":[{"name":"too-big","image":"busybox","resources":{"limits":{"memory":"16Gi"}}}]}}'
```

Expected: `forbidden: maximum memory usage per Container is 12Gi`.

### Egress

```bash
kubectl -n genie-eval run egress-probe --rm -i --restart=Never --image=curlimages/curl --command -- sh -c '
  for u in https://github.com https://codeload.github.com https://api.github.com \
           https://channels.nixos.org https://releases.nixos.org https://tarballs.nixos.org; do
    printf "%s " "$u"; curl -sS -m10 -o /dev/null -w "%{http_code}\n" "$u" || echo FAIL
  done
  printf "example.com "; curl -sS -m5 -o /dev/null https://example.com && echo OPEN || echo BLOCKED
  printf "in-cluster "; curl -sS -m5 -o /dev/null http://synapse.matrix.svc.cluster.local:8008 && echo OPEN || echo BLOCKED
  printf "port-80 "; curl -sS -m5 -o /dev/null http://github.com && echo OPEN || echo BLOCKED'
```

Expected: each fetch host prints an HTTP code (2xx or 3xx), and the last three
lines print `BLOCKED`.

Once runsc (I1) is on the node, repeat this probe under gVisor. That run is I3's
oracle:

```bash
kubectl -n genie-eval run egress-probe --rm -i --restart=Never --image=curlimages/curl \
  --overrides='{"spec":{"runtimeClassName":"gvisor"}}' --command -- sh -c '...same body...'
```

To confirm the drops are the policy and not a network fault:

```bash
kubectl -n kube-system exec ds/cilium -c cilium-agent -- hubble observe --namespace genie-eval --verdict DROPPED --last 20
```

### Watch item: redirect hosts

The allowlist names hosts, not URLs. A fetch host that redirects to a different
hostname (a CDN, an S3 bucket) gets its first response, then the follow-up
fails. Check the redirects:

```bash
kubectl -n genie-eval run redirect-probe --rm -i --restart=Never --image=curlimages/curl --command -- sh -c '
  curl -sSIL -m15 https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz | grep -i "^location"
  curl -sSIL -m15 https://github.com/NixOS/nixpkgs/archive/master.tar.gz | grep -i "^location"'
```

If a redirect target appears that is not in the allowlist, and that fetch fails
in the probe or in a real eval, add the target hostname to `fetchHosts` in
`genie-eval.nix` and to `FETCH_HOSTS` in `genie-eval-check.py`, then re-render
and re-run the check.

## 5. Rollback: remove `genie-eval`

Revert the commit on `main`. `apps` then prunes the `genie-eval` Application,
but the Application carries no resources finalizer and the Namespace is
`Prune=false`. The objects therefore survive and are deleted by hand:

```bash
kubectl -n argocd get application genie-eval        # NotFound once apps has pruned it
kubectl delete ns genie-eval                       # Role, RoleBinding, LimitRange, ResourceQuota, CNP, any Jobs
kubectl -n matrix delete sa genie-eval-launcher
```

The revert also restores `allow-internal-egress` to `endpointSelector: {}`.
Confirm it:

```bash
kubectl get ccnp allow-internal-egress -o jsonpath='{.spec.endpointSelector}{"\n"}'   # {}
```
