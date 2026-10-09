"""Property check over the rendered prod-axon manifests: DNS reachability is
owned by coredns.nix alone.

Usage: dns-egress-check.py <rendered-env-dir>
Exits non-zero, naming every failed property, when one does not hold; refuses
outright when an input is missing or a required object is absent.
"""

import pathlib
import sys

import yaml

EGRESS = "allow-kube-dns-cluster-egress"
INGRESS = "allow-kube-dns-cluster-ingress"
NS_KEY = "k8s:io.kubernetes.pod.namespace"
# The only apps that may grant port-53 egress to endpoints: coredns itself, and
# genie-eval, whose toFQDNs allowlist needs its own L7 DNS rule.
DNS_OWNERS = {"coredns", "genie-eval"}
DNS_PORTS = [{"port": "53", "protocol": "UDP"}, {"port": "53", "protocol": "TCP"}]


def load(path):
    with open(path) as f:
        return [d for d in yaml.safe_load_all(f) if d]


def walk(node, trail=()):
    """Yield (trail, value) for every scalar in node."""
    if isinstance(node, dict):
        for k, v in node.items():
            yield from walk(v, trail + (k,))
    elif isinstance(node, list):
        for v in node:
            yield from walk(v, trail)
    else:
        yield trail, node


def check(policies, deployment):
    fails = []
    pod_labels = deployment["spec"]["template"]["metadata"]["labels"]
    pod_ns = deployment["metadata"]["namespace"]

    def matches_pods(sel, what):
        if sel.get(NS_KEY) != pod_ns:
            fails.append(
                f"{what} namespace {sel.get(NS_KEY)!r} is not CoreDNS's {pod_ns!r}"
            )
        for k, v in sel.items():
            if k != NS_KEY and pod_labels.get(k) != v:
                fails.append(f"{what} {k}={v} does not match CoreDNS pods {pod_labels}")

    def ccnp(name):
        found = [
            p
            for _, p in policies
            if p["kind"] == "CiliumClusterwideNetworkPolicy"
            and p["metadata"]["name"] == name
        ]
        if len(found) != 1:
            sys.exit(f"REFUSED: expected exactly one CCNP {name}, found {len(found)}")
        return found[0]["spec"]

    # (i) The egress half selects every endpoint and reaches exactly the
    # CoreDNS pods on 53, at L4 only; the ingress half selects the same pods.
    egress = ccnp(EGRESS)
    if egress.get("endpointSelector") != {}:
        fails.append(
            f"{EGRESS} selects {egress.get('endpointSelector')}, not every endpoint"
        )
    rules = egress.get("egress", [])
    if len(rules) != 1 or set(rules[0]) != {"toEndpoints", "toPorts"}:
        fails.append(f"{EGRESS} egress is {rules}, want one toEndpoints+toPorts rule")
    else:
        sels = rules[0]["toEndpoints"]
        if len(sels) != 1 or set(sels[0]) != {"matchLabels"}:
            fails.append(f"{EGRESS} toEndpoints is {sels}, want one matchLabels")
        else:
            matches_pods(sels[0]["matchLabels"], f"{EGRESS} selector")
        if rules[0]["toPorts"] != [{"ports": DNS_PORTS}]:
            fails.append(
                f"{EGRESS} toPorts is {rules[0]['toPorts']}, want {DNS_PORTS} with no L7 rules"
            )
    if egress.get("enableDefaultDeny") != {"egress": False, "ingress": False}:
        fails.append(
            f"{EGRESS} enableDefaultDeny is {egress.get('enableDefaultDeny')}, want both false"
        )
    ingress_sel = ccnp(INGRESS).get("endpointSelector", {}).get("matchLabels", {})
    matches_pods(ingress_sel, f"{INGRESS} selector")

    for app, p in policies:
        name = f"{app}/{p['kind']}/{p['metadata']['name']}"
        # (ii) k8s-app=kube-dns is only the Service's label; a pod selector on
        # it matches nothing.
        for trail, v in walk(p):
            if v == "kube-dns" and trail[-1] in ("k8s-app", "k8s:k8s-app"):
                fails.append(
                    f"{name} selects {trail[-1]}=kube-dns at {'.'.join(trail)}"
                )
        # (iii) No app grants its own DNS: port-53 egress to endpoints is
        # coredns.nix's (world 53, e.g. cert-manager's resolvers, is not DNS
        # to CoreDNS and is out of scope).
        if app in DNS_OWNERS:
            continue
        for rule in p["spec"].get("egress", []):
            if "toEndpoints" not in rule:
                continue
            ports = {
                str(pt.get("port"))
                for tp in rule.get("toPorts", [])
                for pt in tp.get("ports", [])
            }
            if "53" in ports:
                fails.append(
                    f"{name} grants its own port-53 egress to {rule['toEndpoints']}"
                )

    return fails


def main():
    env = pathlib.Path(sys.argv[1])
    files = sorted(env.glob("*/Cilium*NetworkPolicy-*.yaml"))
    policies = [(f.parent.name, d) for f in files for d in load(f)]
    if len(policies) < 2:
        sys.exit(f"REFUSED: {len(policies)} Cilium policies under {env}")
    deployment = [
        d
        for d in load(env / "coredns/Deployment-coredns.yaml")
        if d["kind"] == "Deployment"
    ]
    if len(deployment) != 1:
        sys.exit(f"REFUSED: no CoreDNS Deployment under {env}")
    fails = check(policies, deployment[0])
    for f in fails:
        print(f"FAIL {f}")
    if fails:
        sys.exit(1)
    print(f"dns-egress: OK ({len(policies)} policies)")


if __name__ == "__main__":
    main()
