"""Property check over the rendered genie-eval manifests (genie-eval.nix).

Usage: genie-eval-check.py <app-dir> <allow-internal-egress.yaml>
Exits non-zero, naming every failed property, when one does not hold; refuses
outright when an input is missing or a required object is absent.
"""

import pathlib
import sys

import yaml

NS = "genie-eval"
LAUNCHER = ("matrix", "genie-eval-launcher")
ROLE_RULES = {
    ("batch", "jobs", verb) for verb in ("create", "get", "list", "watch", "delete")
} | {
    ("", resource, verb)
    for resource in ("pods", "pods/log")
    for verb in ("get", "list", "watch")
}
FETCH_HOSTS = {
    "github.com",
    "codeload.github.com",
    "api.github.com",
    "channels.nixos.org",
    "releases.nixos.org",
    "tarballs.nixos.org",
}
BOUNDS = {"memory": "12Gi", "cpu": "2"}


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


def check(docs, ccnp):
    fails = []
    by_kind = {}
    for d in docs:
        by_kind.setdefault(d["kind"], []).append(d)

    def one(kind):
        objs = by_kind.get(kind, [])
        if len(objs) != 1:
            sys.exit(f"REFUSED: expected exactly one {kind}, found {len(objs)}")
        return objs[0]

    # No wildcard anywhere. The single exemption is the DNS proxy's L7
    # matchPattern, which inspects lookups and grants no destination.
    for d in docs:
        for trail, v in walk(d):
            if (
                isinstance(v, str)
                and "*" in v
                and trail[-2:] != ("dns", "matchPattern")
            ):
                fails.append(
                    f"wildcard in {d['kind']}/{d['metadata']['name']} at {'.'.join(trail)}: {v!r}"
                )

    role = one("Role")
    if role["metadata"].get("namespace") != NS:
        fails.append(f"Role namespace is {role['metadata'].get('namespace')!r}")
    got = {
        (g, r, v)
        for rule in role.get("rules", [])
        for g in rule.get("apiGroups", [])
        for r in rule.get("resources", [])
        for v in rule.get("verbs", [])
    }
    if got != ROLE_RULES:
        fails.append(
            f"Role grants extra {sorted(got - ROLE_RULES)} missing {sorted(ROLE_RULES - got)}"
        )
    if any(
        set(rule) - {"apiGroups", "resources", "verbs"}
        for rule in role.get("rules", [])
    ):
        fails.append("Role rule carries resourceNames/nonResourceURLs or other fields")

    rb = one("RoleBinding")
    subjects = [
        (s.get("kind"), s.get("namespace"), s.get("name"))
        for s in rb.get("subjects", [])
    ]
    if subjects != [("ServiceAccount", *LAUNCHER)]:
        fails.append(f"RoleBinding subjects are {subjects}")
    if (rb["roleRef"]["kind"], rb["roleRef"]["name"]) != (
        "Role",
        role["metadata"]["name"],
    ):
        fails.append(f"RoleBinding roleRef is {rb['roleRef']}")
    if rb["metadata"].get("namespace") != NS:
        fails.append(f"RoleBinding namespace is {rb['metadata'].get('namespace')!r}")
    for kind in ("ClusterRole", "ClusterRoleBinding"):
        if kind in by_kind:
            fails.append(f"{kind} present")

    sa = one("ServiceAccount")
    if (sa["metadata"].get("namespace"), sa["metadata"]["name"]) != LAUNCHER:
        fails.append(f"ServiceAccount is {sa['metadata']}")

    lr = one("LimitRange")
    containers = [l for l in lr["spec"]["limits"] if l.get("type") == "Container"]
    if len(containers) != 1:
        fails.append(f"LimitRange has {len(containers)} Container entries")
    for entry in containers:
        for field, want in (
            ("max", BOUNDS),
            ("default", BOUNDS),
            ("defaultRequest", BOUNDS),  # request = limit: Guaranteed QoS
        ):
            if entry.get(field) != want:
                fails.append(f"LimitRange {field} is {entry.get(field)}, want {want}")

    rq = one("ResourceQuota")
    if rq["spec"].get("hard", {}).get("pods") != "4":
        fails.append(f"ResourceQuota hard is {rq['spec'].get('hard')}")

    cnp = one("CiliumNetworkPolicy")["spec"]
    if cnp.get("endpointSelector") != {}:
        fails.append(
            f"CNP selects {cnp.get('endpointSelector')}, not the whole namespace"
        )
    if cnp.get("enableDefaultDeny", {}).get("ingress") is not True or cnp.get(
        "ingress"
    ):
        fails.append("CNP does not deny all ingress")
    for trail, v in walk(cnp):
        if "toEntities" in trail:
            fails.append(f"CNP allows entity {v!r}")
        if any(t in ("toCIDR", "toCIDRSet") for t in trail):
            fails.append(f"CNP allows CIDR {v!r}")
    fqdns = {
        s.get("matchName")
        for rule in cnp.get("egress", [])
        for s in rule.get("toFQDNs", [])
    }
    if fqdns != FETCH_HOSTS:
        fails.append(
            f"CNP FQDNs extra {sorted(fqdns - FETCH_HOSTS)} missing {sorted(FETCH_HOSTS - fqdns)}"
        )
    patterns = [
        s
        for rule in cnp.get("egress", [])
        for s in rule.get("toFQDNs", [])
        if "matchName" not in s
    ]
    if patterns:
        fails.append(f"CNP FQDN selectors other than matchName: {patterns}")
    for rule in cnp.get("egress", []):
        if "toFQDNs" in rule:
            continue
        sel = rule.get("toEndpoints", [])
        dns = {"k8s:io.kubernetes.pod.namespace": "kube-system", "k8s-app": "kube-dns"}
        if sel != [{"matchLabels": dns}]:
            fails.append(f"CNP egress to endpoints other than kube-dns: {sel}")

    # Cilium policies only add allows: the cluster-wide in-cluster grant must
    # not select this namespace, or the CNP above denies nothing in-cluster.
    if [c["metadata"]["name"] for c in ccnp] != ["allow-internal-egress"]:
        sys.exit("REFUSED: allow-internal-egress manifest not found")
    exprs = ccnp[0]["spec"].get("endpointSelector", {}).get("matchExpressions", [])
    excluded = any(
        e.get("key") == "k8s:io.kubernetes.pod.namespace"
        and e.get("operator") == "NotIn"
        and NS in e.get("values", [])
        for e in exprs
    )
    if not excluded or ccnp[0]["spec"]["endpointSelector"].get("matchLabels"):
        fails.append(
            f"allow-internal-egress still selects {NS}: {ccnp[0]['spec']['endpointSelector']}"
        )

    return fails


def main():
    app_dir, ccnp_file = map(pathlib.Path, sys.argv[1:3])
    files = sorted(app_dir.glob("*.yaml"))
    if not files:
        sys.exit(f"REFUSED: no manifests under {app_dir}")
    docs = [d for f in files for d in load(f)]
    fails = check(docs, load(ccnp_file))
    for f in fails:
        print(f"FAIL {f}")
    if fails:
        sys.exit(1)
    print(f"genie-eval: OK ({len(docs)} objects)")


if __name__ == "__main__":
    main()
