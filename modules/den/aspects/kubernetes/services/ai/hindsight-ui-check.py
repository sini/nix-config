"""Render check for the hindsight exposure (hindsight.nix, kanidm.nix).

  python3 hindsight-ui-check.py <rendered prod-axon env> <base rendered env> <kanidm-oauth2.json>

kanidm-oauth2.json is `nix eval --json .#nixosConfigurations.uplink.config.services.kanidm.provision.systems.oauth2.hindsight`.

  ui   the HTTPRoute serves hindsight-cp behind an OIDC SecurityPolicy whose kanidm
       client maps only the `admins` group
  cp   nothing but the gateway reaches the CP: every Service selecting it is
       ClusterIP, the only (clusterwide or ai) network policy giving it ingress admits
       just the gateways namespace, and no other route points at it
  dp   the dataplane's Services and its Prometheus and LAN policies are byte-identical
       to the base render; no policy on 8888 carries HTTP rules except tier-1's
       recall allow-list, which is present (no Envoy proxy for anyone else); the
       deployment has document import enabled

Exit 0 iff every check passes; every failure is printed.
"""

import json
import os
import sys
from pathlib import Path

import yaml

env, base, kanidm = (
    Path(sys.argv[1]),
    Path(sys.argv[2]),
    json.loads(Path(sys.argv[3]).read_text()),
)
fails: list[str] = []
# Some CRD schemas carry a bare `=`, which PyYAML reads as the value tag.
yaml.SafeLoader.add_constructor(
    "tag:yaml.org,2002:value", lambda loader, node: loader.construct_scalar(node)
)


def check(name, ok, detail):
    print(f"{'ok  ' if ok else 'FAIL'} {name}: {detail}")
    if not ok:
        fails.append(name)


docs = []
# The env's app directories are symlinks, which Path.rglob does not follow.
yamls = sorted(
    Path(d) / n
    for d, _, ns in os.walk(env, followlinks=True)
    for n in ns
    if n.endswith(".yaml")
)
for f in yamls:
    for d in yaml.safe_load_all(f.read_text()):
        if isinstance(d, dict):
            docs.append((f, d))
if not docs:
    sys.exit(f"no manifests under {env}")


def kind(k):
    return [d for _, d in docs if d.get("kind") == k]


cp = next(
    d
    for d in kind("Deployment")
    if d["metadata"]["name"] == "hindsight-cp" and d["metadata"]["namespace"] == "ai"
)
cp_labels = dict(cp["spec"]["template"]["metadata"]["labels"])
cp_identity = {
    **cp_labels,
    "k8s:io.kubernetes.pod.namespace": "ai",
    "io.kubernetes.pod.namespace": "ai",
}
for k, v in cp_labels.items():
    cp_identity[f"k8s:{k}"] = v


def selects(sel, labels):
    for k, v in (sel.get("matchLabels") or {}).items():
        if labels.get(k) != v and labels.get(k.removeprefix("k8s:")) != v:
            return False
    for e in sel.get("matchExpressions") or []:
        k, op, vals = e["key"], e["operator"], e.get("values", [])
        have = labels.get(k, labels.get(k.removeprefix("k8s:")))
        if (
            (op == "In" and have not in vals)
            or (op == "NotIn" and have in vals)
            or (op == "Exists" and have is None)
            or (op == "DoesNotExist" and have is not None)
        ):
            return False
    return True


# ui
routes = [r for r in kind("HTTPRoute") if r["metadata"]["namespace"] == "ai"]
ui = next((r for r in routes if r["metadata"]["name"] == "hindsight"), None)
check("ui.route", ui is not None, "HTTPRoute ai/hindsight present")
if ui:
    backends = [b for rule in ui["spec"]["rules"] for b in rule["backendRefs"]]
    check(
        "ui.backend",
        backends == [{"name": "hindsight-cp", "port": 3000}],
        f"backends {backends}",
    )
pols = [
    p
    for p in kind("SecurityPolicy")
    if p["metadata"]["namespace"] == "ai"
    and any(
        t.get("kind") == "HTTPRoute" and t.get("name") == "hindsight"
        for t in p["spec"]["targetRefs"]
    )
]
oidc = pols[0]["spec"].get("oidc", {}) if len(pols) == 1 else {}
check(
    "ui.oidc",
    oidc.get("clientID") == "hindsight",
    f"{len(pols)} SecurityPolicy, clientID {oidc.get('clientID')}",
)
groups = sorted((kanidm.get("scopeMaps") or {}).keys())
check(
    "ui.admins-only",
    groups == ["admins"],
    f"kanidm hindsight scopeMaps groups {groups}",
)

# cp
for s in kind("Service"):
    sel = s["spec"].get("selector") or {}
    if (
        s["metadata"].get("namespace") == "ai"
        and sel
        and all(cp_labels.get(k) == v for k, v in sel.items())
    ):
        t = s["spec"].get("type", "ClusterIP")
        node_ports = [p for p in s["spec"].get("ports", []) if "nodePort" in p]
        check(
            "cp.service",
            t == "ClusterIP" and not node_ports,
            f"Service {s['metadata']['name']} type={t}",
        )
ingress_pols = []
for p in kind("CiliumNetworkPolicy") + kind("CiliumClusterwideNetworkPolicy"):
    clusterwide = p["kind"] == "CiliumClusterwideNetworkPolicy"
    if not clusterwide and p["metadata"].get("namespace") != "ai":
        continue
    for spec in [p["spec"]] if "spec" in p else p.get("specs", []):
        if spec.get("ingress") and selects(
            spec.get("endpointSelector", {}), cp_identity
        ):
            ingress_pols.append((p["metadata"]["name"], spec["ingress"]))
names = [n for n, _ in ingress_pols]
check(
    "cp.ingress-policies",
    names == ["allow-gateway-ingress-hindsight-cp"],
    f"policies giving the CP ingress: {names}",
)
for n, rules in ingress_pols:
    peers = [{k: v for k, v in r.items() if k != "toPorts"} for r in rules]
    want = [
        {
            "fromEndpoints": [
                {"matchLabels": {"k8s:io.kubernetes.pod.namespace": "gateways"}}
            ]
        }
    ]
    check("cp.ingress-peers", peers == want, f"{n} peers {peers}")
others = [
    f"{r['kind']} {r['metadata']['namespace']}/{r['metadata']['name']}"
    for r in kind("HTTPRoute") + kind("GRPCRoute") + kind("TCPRoute") + kind("TLSRoute")
    if any(
        b.get("name") == "hindsight-cp"
        for rule in r["spec"].get("rules", [])
        for b in rule.get("backendRefs", [])
    )
    and r["metadata"]["name"] != "hindsight"
]
check("cp.no-other-route", not others, f"other routes to hindsight-cp: {others}")

# dp
for f in (
    "hindsight/Service-hindsight.yaml",
    "hindsight/Service-hindsight-internal.yaml",
    "hindsight/CiliumNetworkPolicy-allow-metrics-ingress-hindsight.yaml",
    "hindsight/CiliumNetworkPolicy-allow-lan-ingress-hindsight.yaml",
):
    a, b = base / f, env / f
    check(
        "dp.unchanged",
        a.is_file() and b.is_file() and a.read_bytes() == b.read_bytes(),
        f,
    )

dp = next(
    d
    for d in kind("Deployment")
    if d["metadata"]["name"] == "hindsight" and d["metadata"]["namespace"] == "ai"
)
dp_identity = {
    **dict(dp["spec"]["template"]["metadata"]["labels"]),
    "io.kubernetes.pod.namespace": "ai",
}
l7 = []
for p in kind("CiliumNetworkPolicy") + kind("CiliumClusterwideNetworkPolicy"):
    if p["kind"] == "CiliumNetworkPolicy" and p["metadata"].get("namespace") != "ai":
        continue
    for spec in [p["spec"]] if "spec" in p else p.get("specs", []):
        if not selects(spec.get("endpointSelector", {}), dp_identity):
            continue
        for rule in spec.get("ingress") or []:
            for tp in rule.get("toPorts") or []:
                if (tp.get("rules") or {}).get("http"):
                    l7.append(p["metadata"]["name"])
check(
    "dp.l7-only-tier1",
    l7 == ["allow-genie-tier1-recall-hindsight"],
    f"policies with HTTP rules on the dataplane: {l7}",
)
envs = {
    e["name"]: e.get("value")
    for c in dp["spec"]["template"]["spec"]["containers"]
    for e in c.get("env", [])
}
imp = envs.get("HINDSIGHT_API_ENABLE_DOCUMENT_IMPORT_API")
check(
    "dp.import-enabled",
    imp in (None, "true"),
    f"HINDSIGHT_API_ENABLE_DOCUMENT_IMPORT_API={imp!r}",
)

print(f"FAILED {len(fails)}" if fails else "ALL PASS")
sys.exit(1 if fails else 0)
