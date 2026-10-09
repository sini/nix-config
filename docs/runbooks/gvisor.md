# Runbook: the gVisor (runsc) runtime on axon

Pods with `runtimeClassName: gvisor` run under gVisor's `runsc` instead of
`runc`. Two pieces:

- `settings.services.k3s.gvisor` (per host, default off) adds the containerd
  `runsc` handler (`modules/den/aspects/services/k3s/containerd.nix`), puts
  `pkgs.gvisor` (`runsc`, `containerd-shim-runsc-v1`) on containerd's PATH, and
  labels the node `node.kubernetes.io/gvisor=true` (`k3s.nix`). Only **axon-01**
  enables it.
- `kubernetes.hardware.gvisor` emits RuntimeClass `gvisor` (handler `runsc`,
  `scheduling.nodeSelector` on that label), so a gvisor pod is only scheduled
  onto a node that has the handler.

## 1. Pre-deploy check

From the repo root:

```bash
docs/runbooks/gvisor-oracle.sh
```

It exits 0 when axon-01 has the handler and axon-02 doesn't, and the rendered
manifests contain the RuntimeClass. It exits 1 if a property fails and 2 if it
can't evaluate.

## 2. Deploy axon-01

```bash
colmena apply --on axon-01
```

The containerd config change restarts containerd and k3s on that node. Then let
ArgoCD sync the `gvisor` Application.

k3s may apply `--node-label` only when a node first registers, so check that the
label is there:

```bash
kubectl get node axon-01 -L node.kubernetes.io/gvisor
# if the column is empty:
kubectl label node axon-01 node.kubernetes.io/gvisor=true
kubectl get runtimeclass gvisor
```

## 3. Live check: gVisor kernel vs runc control

```bash
for rt in gvisor runc; do
  kubectl -n default apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: rt-probe-$rt
spec:
  restartPolicy: Never
  nodeSelector:
    kubernetes.io/hostname: axon-01
  $( [ "$rt" = gvisor ] && echo "runtimeClassName: gvisor" )
  containers:
    - name: probe
      image: docker.io/library/busybox:1.37
      command: ["sh", "-c", "dmesg 2>&1 | head -5; uname -r"]
EOF
done
kubectl -n default wait --for=jsonpath='{.status.phase}'=Succeeded pod/rt-probe-gvisor pod/rt-probe-runc --timeout=120s
kubectl -n default logs rt-probe-gvisor
kubectl -n default logs rt-probe-runc
kubectl -n default delete pod rt-probe-gvisor rt-probe-runc
```

Expected:

- `rt-probe-gvisor`: the first line is `[    0.000000] Starting gVisor...`,
  followed by gVisor's joke boot lines, and `uname -r` shows gVisor's synthetic
  version (`4.4.0`).
- `rt-probe-runc`: no `gVisor` line. `dmesg` is denied
  (`Operation not permitted`) or shows the host kernel's log, and `uname -r` is
  the host kernel.

If the gvisor pod is stuck `ContainerCreating` with
`no runtime for "runsc" is configured`, containerd is still on the old config.
Check `systemctl status containerd` on axon-01. If the pod is `Pending` with a
node-affinity mismatch, the label from step 2 is missing.

## Rollback

Remove `services.k3s.gvisor = true;` from `modules/den/hosts/axon-01.nix` and
redeploy. The RuntimeClass can stay, since without a labelled node a gvisor pod
just stays Pending.
