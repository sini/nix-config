# Runbook: Observability changes (Alloy · Prometheus · Loki · Grafana)

**Cluster:** axon k3s · **Namespace:** `monitoring`

The k8s stack watches cluster workloads; uplink's host stack watches hosts from
outside. Node metrics belong to the hosts (node-exporter is off in the chart).

```bash
export KUBECONFIG=$HOME/.config/kube/config
```

## Before shipping an Alloy config

Validate every River file. A malformed DaemonSet config breaks logging
cluster-wide, and a malformed sidecar crash-loops while the stdout drop is still
active, so that app ships nothing.

```bash
nix run nixpkgs#grafana-alloy -- fmt <file>
```

River comments are `//`. A `#` is a parse error.

## Verifying

The Prometheus, Loki and Grafana images are distroless (no shell, no wget), so
query them from the workstation through a port-forward:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090 &
curl -s --retry 5 --retry-connrefused 'localhost:9090/api/v1/targets?state=active'

kubectl -n monitoring port-forward svc/loki 3100 &
curl -s --retry 5 --retry-connrefused -G localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={namespace="media"}' --data-urlencode "start=$(date -d -5min +%s)000000000"
```

`kubectl get --raw /api/v1/namespaces/monitoring/services/http:kube-prometheus-stack-prometheus:9090/proxy/api/v1/...`
works too, without a port-forward.

When checking that a file-tailed app has no duplicate stdout stream, query a
window that starts after the pod settled: a few main-container lines leak at
startup before Alloy's discovery applies the drop.

## Log paths

Read an app's real log directory from the live pod before pointing a tail at it;
several differ from their docs (bazarr `/config/log/`, qBittorrent
`/config/qBittorrent/logs/`, Servarr `/config/logs/*.txt`).

## Secrets for a new k8s service

A new agenix secret consumed by the cluster takes four steps, in order:

```bash
nix run .#agenix-rekey.x86_64-linux.generate   # create the master-encrypted source
nix run .#agenix-rekey.x86_64-linux.rekey      # per-host copies (e.g. kanidm on uplink)
nix run .#sops-rekey                           # copy it into .secrets/clusters/<c>/sops/*.enc.yaml
nixidy-sync                                    # render the SopsSecret manifest (YubiKey)
```

`sops-rekey` only re-encrypts sources that already exist; `generate` is what
creates one (or encrypt a hand-supplied value yourself).
