"""Render check for the hindsight dataplane's HTTP allow-list (hindsight.nix).

  python3 hindsight-l7-check.py <rendered prod-axon env> <base rendered env> <routes.json>

routes.json is hindsight-api 0.9.2's route table, [[method, path], ...], dumped from
create_app (hindsight-0.9.2-routes.json beside this file). Every route, plus the MCP
endpoint, is evaluated for each source against the CiliumNetworkPolicies selecting
the dataplane pod on 8888, with Cilium's semantics: a source gets the union of the
rules it matches, a rule without HTTP rules admits everything, HTTP method and path
are full-match regexes.

  import    POST …/document-transfer is admitted for exactly cortex, bitstream and
            genie/genie-expert
  same      every other route is admitted for every source exactly as in the base
  env       the deployment has document import enabled

Exit 0 iff every check passes; every failure is printed.
"""

import ipaddress
import json
import os
import re
import sys
from pathlib import Path

import yaml

yaml.SafeLoader.add_constructor(
    "tag:yaml.org,2002:value", lambda loader, node: loader.construct_scalar(node)
)

NS, SA, APP = (
    "io.kubernetes.pod.namespace",
    "io.cilium.k8s.policy.serviceaccount",
    "app.kubernetes.io/name",
)
SOURCES = {
    "prometheus": {"labels": {NS: "monitoring", APP: "prometheus"}},
    "control-plane": {"labels": {NS: "ai", APP: "hindsight-cp"}},
    "lan-host": {"ip": "10.9.3.7"},
    "cortex": {"ip": "10.9.2.1"},
    "bitstream": {"ip": "10.9.1.1"},
    "genie-tier1": {"labels": {NS: "genie", SA: "genie-tier1"}},
    "genie-expert": {"labels": {NS: "genie", SA: "genie-expert"}},
}
IMPORT = ("POST", "/v1/default/banks/{bank_id}/document-transfer")
IMPORTERS = {"cortex", "bitstream", "genie-expert"}


def load(env):
    docs = []
    for d, _, ns in os.walk(env, followlinks=True):
        for n in ns:
            if n.endswith(".yaml"):
                docs += [
                    x
                    for x in yaml.safe_load_all((Path(d) / n).read_text())
                    if isinstance(x, dict)
                ]
    if not docs:
        sys.exit(f"no manifests under {env}")
    return docs


def selects(sel, labels):
    for k, v in (sel.get("matchLabels") or {}).items():
        if labels.get(k.removeprefix("k8s:")) != v:
            return False
    for e in sel.get("matchExpressions") or []:
        have = labels.get(e["key"].removeprefix("k8s:"))
        op, vals = e["operator"], e.get("values", [])
        if (op == "In" and have not in vals) or (op == "NotIn" and have in vals):
            return False
        if (op == "Exists" and have is None) or (
            op == "DoesNotExist" and have is not None
        ):
            return False
    return True


def rules_for(docs):
    """(peer predicate, http rules or None) for every ingress rule on the dataplane's 8888."""
    dp = next(
        d
        for d in docs
        if d.get("kind") == "Deployment"
        and d["metadata"]["name"] == "hindsight"
        and d["metadata"].get("namespace") == "ai"
    )
    pod = {**dp["spec"]["template"]["metadata"]["labels"], NS: "ai"}
    out = []
    for p in docs:
        if p.get("kind") not in (
            "CiliumNetworkPolicy",
            "CiliumClusterwideNetworkPolicy",
        ):
            continue
        if (
            p["kind"] == "CiliumNetworkPolicy"
            and p["metadata"].get("namespace") != "ai"
        ):
            continue
        for spec in [p["spec"]] if "spec" in p else p.get("specs", []):
            if not selects(spec.get("endpointSelector", {}), pod):
                continue
            for rule in spec.get("ingress") or []:
                cidrs = [ipaddress.ip_network(c) for c in rule.get("fromCIDR", [])]
                eps = rule.get("fromEndpoints", [])

                def peer(src, cidrs=cidrs, eps=eps):
                    if "ip" in src:
                        return any(ipaddress.ip_address(src["ip"]) in c for c in cidrs)
                    return any(selects(e, src["labels"]) for e in eps)

                ports = rule.get("toPorts")
                if not ports:
                    out.append((p["metadata"]["name"], peer, None))
                for tp in ports or []:
                    if any(str(x.get("port")) == "8888" for x in tp.get("ports", [])):
                        out.append(
                            (
                                p["metadata"]["name"],
                                peer,
                                (tp.get("rules") or {}).get("http"),
                            )
                        )
    return out


def admitted(rules, src, method, path):
    for _, peer, http in rules:
        if not peer(src):
            continue
        if http is None:
            return True
        for h in http:
            if re.fullmatch(h.get("method", ".*"), method) and re.fullmatch(
                h.get("path", ".*"), path
            ):
                return True
    return False


def concrete(path):
    path = path.replace("{document_id:path}", "d/1")
    return re.sub(r"\{[^}]+\}", "x0", path)


env, base = load(Path(sys.argv[1])), load(Path(sys.argv[2]))
routes = [tuple(r) for r in json.loads(Path(sys.argv[3]).read_text())]
routes += [
    ("POST", "/mcp/den-law/"),
    ("GET", "/mcp/den-law/"),
    ("DELETE", "/mcp/den-law/"),
]
new_rules, base_rules = rules_for(env), rules_for(base)
fails = []


def check(name, ok, detail):
    if not ok:
        print(f"FAIL {name}: {detail}")
        fails.append(name)


n = 0
for method, route in routes:
    paths = [concrete(route)] + (
        [concrete(route) + "?limit=1"] if method == "GET" else []
    )
    for path in paths:
        for name, src in SOURCES.items():
            now = admitted(new_rules, src, method, path)
            n += 1
            if (method, route) == IMPORT:
                check(
                    "import",
                    now == (name in IMPORTERS),
                    f"{name} {method} {path} admitted={now}",
                )
            else:
                was = admitted(base_rules, src, method, path)
                check(
                    "same",
                    now == was,
                    f"{name} {method} {path} admitted={now} base={was}",
                )
print(
    f"evaluated {n} (source, request) pairs over {len(routes)} routes and {len(SOURCES)} sources"
)

dp = next(
    d
    for d in env
    if d.get("kind") == "Deployment" and d["metadata"]["name"] == "hindsight"
)
envs = {
    e["name"]: e.get("value")
    for c in dp["spec"]["template"]["spec"]["containers"]
    for e in c.get("env", [])
}
imp = envs.get("HINDSIGHT_API_ENABLE_DOCUMENT_IMPORT_API")
check("env", imp in (None, "true"), f"HINDSIGHT_API_ENABLE_DOCUMENT_IMPORT_API={imp!r}")

print(f"FAILED {len(fails)}" if fails else "ALL PASS")
sys.exit(1 if fails else 0)
