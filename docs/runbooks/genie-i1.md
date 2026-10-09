# Runbook: genie I1, the gVisor (runsc) runtime on axon-01

Pods with `runtimeClassName: gvisor` run under gVisor's `runsc` instead of
`runc`. This is what isolates the genie eval Jobs. Two operational changes:

- **Host (axon-01):** `settings.services.k3s.gvisor = true` adds the containerd
  `runsc` handler (`modules/den/aspects/services/k3s/containerd.nix`), puts
  `pkgs.gvisor` (`runsc`, `containerd-shim-runsc-v1`) on containerd's PATH, and
  labels the node `node.kubernetes.io/gvisor=true` (`k3s.nix`). Only axon-01
  enables it; axon-02/03 are unchanged.
- **Cluster (axon):** `kubernetes.hardware.gvisor` emits RuntimeClass `gvisor`
  (handler `runsc`, `scheduling.nodeSelector` on that label) as the ArgoCD
  Application `gvisor`. A gvisor pod is only scheduled onto a labelled node.

Order matters: the node gets the handler first (step 2), then the RuntimeClass
appears (step 3). The reverse order is harmless (gvisor pods stay Pending) but
leaves step 4 unrunnable.

## 1. Pre-checks

From the repo root, on the commit you are deploying:

```bash
docs/runbooks/gvisor-oracle.sh; echo "exit=$?"
```

Expected (`exit=0`):

```
PASS axon-01: [runsc handler, gvisor on containerd PATH, gvisor label] = [true,true,true]
PASS axon-02: [runsc handler, gvisor on containerd PATH, gvisor label] = [false,false,false]
PASS manifests: gvisor/RuntimeClass-gvisor.yaml is RuntimeClass gvisor, handler runsc
exit=0
```

`exit=1` means a property failed: don't deploy. `exit=2` means it couldn't
evaluate: read the error, don't take it as a pass.

The cluster is healthy and axon-01 is Ready:

```bash
export KUBECONFIG=$HOME/.config/kube/config
kubectl get nodes
```

Expected: axon-01, axon-02 and axon-03 all `Ready`.

## 2. Deploy axon-01 (host)

```bash
colmena apply --on axon-01
```

This changes the containerd config, so containerd and k3s restart on axon-01.
Its pods restart in place: expect a short disruption to workloads on that node.

Verify:

```bash
ssh axon-01 'systemctl is-active containerd k3s; containerd config dump | grep -A2 "runtimes.runsc"; systemctl show containerd -p Environment | tr " " "\n" | grep ^PATH'
kubectl get node axon-01 -L node.kubernetes.io/gvisor
```

Expected:

- `active` twice.
- A `[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.runsc]` block
  with `runtime_type = "io.containerd.runsc.v1"`.
- containerd's PATH contains a `gvisor-20260406.0/bin` entry. The login shell
  won't have the shim; that's expected.
- axon-01 `Ready`, with `true` in the `GVISOR` column.

k3s may apply `--node-label` only when a node first registers. If the `GVISOR`
column is empty, set the label by hand. It's the same label the flag declares:

```bash
kubectl label node axon-01 node.kubernetes.io/gvisor=true
```

**Rollback:** delete `services.k3s.gvisor = true;` from
`modules/den/hosts/axon-01.nix`, `colmena apply --on axon-01`, then
`kubectl label node axon-01 node.kubernetes.io/gvisor-`. If axon-01 doesn't come
back `Ready`, roll back the host with
`ssh axon-01 sudo nixos-rebuild switch --rollback`.

## 3. Sync the RuntimeClass (cluster)

The `gvisor` Application tracks `main` with automated sync. Once this branch is
on `main`, ArgoCD creates it through the `apps` Application. To sync now instead
of waiting for the poll:

```bash
kubectl -n argocd annotate application apps argocd.argoproj.io/refresh=hard --overwrite
kubectl -n argocd get application gvisor
kubectl get runtimeclass gvisor -o yaml
```

Expected:

- Application `gvisor` reports `Synced` / `Healthy`.
- The RuntimeClass shows `handler: runsc` and
  `scheduling.nodeSelector: {node.kubernetes.io/gvisor: "true"}`.

**Rollback:** remove `hardware.gvisor` from the `den.aspects.axon` includes in
`modules/den/clusters/axon.nix`, run `nixidy-sync --skip-secrets`, and land it
on `main`. ArgoCD prunes the Application and the RuntimeClass. Do this only
after no pod uses `runtimeClassName: gvisor`.

## 4. Live verification: gVisor kernel vs a runc control

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
```

Expected:

- `rt-probe-gvisor`: the first line is `[    0.000000] Starting gVisor...`,
  followed by gVisor's joke boot lines, and `uname -r` shows gVisor's synthetic
  version (`4.4.0` in gVisor's docs).
- `rt-probe-runc`: no `gVisor` line. `dmesg` is denied
  (`Operation not permitted`) or shows the host kernel's log, and `uname -r` is
  axon-01's kernel (compare `ssh axon-01 uname -r`).

Troubleshooting:

- **gvisor pod stuck `ContainerCreating`**, event
  `no runtime for "runsc" is configured`: containerd is on the old config.
  Recheck step 2.
- **gvisor pod `Pending`**, event
  `node(s) didn't match Pod's node affinity/selector`: the label is missing.
  Recheck step 2's label.
- **gvisor pod fails at sandbox start**: the runsc shim or the zfs snapshotter.
  Get the errors with
  `ssh axon-01 journalctl -u containerd --since -10min | grep -i runsc`.

Clean up (this step makes no change to roll back):

```bash
kubectl -n default delete pod rt-probe-gvisor rt-probe-runc
```
