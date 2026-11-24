"""Property check over the rendered prod-axon manifests: the cortex-cuda model
ports are reachable only by the allow-listed (namespace, service account) pairs
(model-egress.nix).

Usage: model-egress-check.py <rendered-env-dir>
Exits non-zero, naming every failed property, when one does not hold; refuses
outright when an input is missing or a required object is absent.
"""

import ipaddress
import pathlib
import sys

import yaml

APP = "model-egress"
BASELINE = "allow-internal-egress"
CIDR = "10.9.2.2/32"
TARGET = ipaddress.ip_network(CIDR)
PORTS = {("8081", "TCP"), ("18020", "TCP")}
ALLOW = {("genie", "genie-guard"), ("genie", "genie-tier1")}
NS_KEY = "k8s:io.kubernetes.pod.namespace"
SA_KEY = "k8s:io.cilium.k8s.policy.serviceaccount"
# L3 fields that name a destination; a rule with none of them reaches anywhere.
L3 = {
    "toEndpoints",
    "toEntities",
    "toCIDR",
    "toCIDRSet",
    "toFQDNs",
    "toServices",
    "toGroups",
    "toNodes",
    "toRequires",
}


def load(path):
    with open(path) as f:
        return [d for d in yaml.safe_load_all(f) if d]


def specs(p):
    return ([p["spec"]] if "spec" in p else []) + p.get("specs", [])


def selects(selector, labels):
    """Kubernetes label-selector semantics; NotIn and DoesNotExist match an absent key."""
    for k, v in selector.get("matchLabels", {}).items():
        if labels.get(k) != v:
            return False
    for e in selector.get("matchExpressions", []):
        k, op, vals = e["key"], e["operator"], e.get("values", [])
        present = k in labels
        ok = {
            "In": present and labels.get(k) in vals,
            "NotIn": not present or labels[k] not in vals,
            "Exists": present,
            "DoesNotExist": not present,
        }.get(op)
        if ok is None:
            sys.exit(f"REFUSED: unknown selector operator {op!r}")
        if not ok:
            return False
    return True


def reaches_target(rule):
    """Whether an egress allow rule can admit TARGET on one of PORTS."""
    if not set(rule) & L3:
        hit = True
    else:
        hit = any(
            e in ("world", "world-ipv4", "all") for e in rule.get("toEntities", [])
        )
        cidrs = rule.get("toCIDR", []) + [
            s["cidr"] for s in rule.get("toCIDRSet", []) if "cidr" in s
        ]
        for c in cidrs:
            net = ipaddress.ip_network(c, strict=False)
            if net.version == 4 and TARGET.subnet_of(net):
                hit = True
    if not hit:
        return False
    ports = [p for tp in rule.get("toPorts", []) for p in tp.get("ports", [])]
    if not ports:
        return True
    for p in ports:
        lo = int(p.get("port") or 0)
        hi = int(p.get("endPort") or lo)
        if lo == 0 or any(lo <= int(port) <= hi for port, _ in PORTS):
            return True
    return False


def check(policies):
    fails = []

    # The baseline that makes this an allow-list: a policy with egress rules
    # and no egress opt-out puts every pod it selects into egress default-deny.
    base = [
        p
        for _, p in policies
        if p["kind"] == "CiliumClusterwideNetworkPolicy"
        and p["metadata"]["name"] == BASELINE
    ]
    if len(base) != 1:
        sys.exit(f"REFUSED: expected exactly one CCNP {BASELINE}, found {len(base)}")
    b = base[0]["spec"]
    if b.get("enableDefaultDeny", {}).get("egress") is False:
        fails.append(f"{BASELINE} opts out of egress default-deny")
    if b.get("egress") != [{"toEndpoints": [{}]}]:
        fails.append(f"{BASELINE} egress is {b.get('egress')}, want in-cluster only")

    own = [p for app, p in policies if app == APP]
    if not own:
        sys.exit(f"REFUSED: no policies under {APP}/")
    own_specs = []
    for p in own:
        name = p["metadata"]["name"]
        if p["kind"] != "CiliumClusterwideNetworkPolicy":
            fails.append(f"{APP}/{p['kind']}/{name} is not a CCNP")
        for s in specs(p):
            own_specs.append(s)
            if set(s) - {"description", "egress", "endpointSelector"}:
                fails.append(f"{name} carries {sorted(s)}, want egress allow only")
            for rule in s.get("egress", []):
                ports = {
                    (pt.get("port"), pt.get("protocol"))
                    for tp in rule.get("toPorts", [])
                    for pt in tp.get("ports", [])
                }
                if (
                    set(rule) != {"toCIDR", "toPorts"}
                    or rule["toCIDR"] != [CIDR]
                    or ports != PORTS
                    or any(set(tp) != {"ports"} for tp in rule["toPorts"])
                ):
                    fails.append(
                        f"{name} allows {rule}, want toCIDR [{CIDR}] on {sorted(PORTS)} only"
                    )
            if not s.get("egress"):
                fails.append(f"{name} has no egress rule")

    # A pod gets the model allow exactly when its (namespace, sa) is listed.
    namespaces = {ns for ns, _ in ALLOW} | {"default", "kube-system", "ai"}
    sas = {sa for _, sa in ALLOW} | {"default", "hindsight", None}
    for ns in sorted(namespaces):
        for sa in sorted(sas, key=str):
            labels = {NS_KEY: ns} | ({SA_KEY: sa} if sa is not None else {})
            allowed = any(
                selects(s.get("endpointSelector", {}), labels) for s in own_specs
            )
            if allowed != ((ns, sa) in ALLOW):
                fails.append(
                    f"pod {ns}/{sa}: allowed={allowed}, listed={(ns, sa) in ALLOW}"
                )

    # Nothing else admits the model ports.
    for app, p in policies:
        if app == APP:
            continue
        for s in specs(p):
            for rule in s.get("egress", []):
                if reaches_target(rule):
                    fails.append(
                        f"{app}/{p['kind']}/{p['metadata']['name']} admits {CIDR} model ports: {rule}"
                    )

    return fails


def main():
    env = pathlib.Path(sys.argv[1])
    files = sorted(env.glob("*/Cilium*NetworkPolicy-*.yaml"))
    policies = [(f.parent.name, d) for f in files for d in load(f)]
    if len(policies) < 2:
        sys.exit(f"REFUSED: {len(policies)} Cilium policies under {env}")
    fails = check(policies)
    for f in fails:
        print(f"FAIL {f}")
    if fails:
        sys.exit(1)
    print(f"model-egress: OK ({len(policies)} policies)")


if __name__ == "__main__":
    main()
