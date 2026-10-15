"""Property check over genie-guard.nix's manifests (flag forced on): pod hardening,
the leaf certificate, the egress policy, the register socket shared by both
containers, and the leaf's xmsg arguments and peers file.

Usage: genie-guard-check.py <manifests.json>
Exits non-zero, naming every failed property, when one does not hold.
"""

import json
import posixpath
import sys

NS, SA = "genie", "genie-guard"
UID = 65532
IDENTITY = f"spiffe://json64.dev/ns/{NS}/sa/{SA}"
ISSUER = "xmsg-cluster-ca"
# The hub's node name, and bitstream's LAN address and its owner's federation port.
HUB = "sini.bitstream"
EGRESS = {("10.9.1.1/32", "7788", "TCP")}
NS_KEY = "k8s:io.kubernetes.pod.namespace"
SA_KEY = "k8s:io.cilium.k8s.policy.serviceaccount"

failed = []


def check(name, ok, detail=""):
    if not ok:
        failed.append(f"{name}: {detail}" if detail else name)


with open(sys.argv[1]) as f:
    app = json.load(f)["applications"][SA]
res = app["resources"]
check("namespace", app["namespace"] == NS, app.get("namespace"))
check(
    "no Service or ingress", not ({"services", "ingresses", "httpRoutes"} & res.keys())
)

# 1. Pod hardening.
pod = res["deployments"][SA]["spec"]["template"]["spec"]
containers = {c["name"]: c for c in pod["containers"]}
volumes = {v["name"]: v for v in pod.get("volumes", [])}
check("two containers", set(containers) == {"xmsg", SA}, sorted(containers))
check("pod service account", pod.get("serviceAccountName") == SA)
check("pod token not automounted", pod.get("automountServiceAccountToken") is False)
check(
    "SA token not automounted",
    res["serviceAccounts"][SA].get("automountServiceAccountToken") is False,
)
check("no runtimeClassName", "runtimeClassName" not in pod)
for n, c in containers.items():
    sc = c.get("securityContext", {})
    caps = sc.get("capabilities", {})
    check(f"{n} runAsUser", sc.get("runAsUser") == UID, sc.get("runAsUser"))
    check(f"{n} runAsGroup", sc.get("runAsGroup") == UID, sc.get("runAsGroup"))
    check(f"{n} runAsNonRoot", sc.get("runAsNonRoot") is True)
    check(f"{n} readOnlyRootFilesystem", sc.get("readOnlyRootFilesystem") is True)
    check(f"{n} no privilege escalation", sc.get("allowPrivilegeEscalation") is False)
    check(
        f"{n} all capabilities dropped",
        caps.get("drop") == ["ALL"] and not caps.get("add"),
        caps,
    )
    check(f"{n} image digest-pinned", "@sha256:" in c.get("image", ""), c.get("image"))
    tmp = {m["name"] for m in c.get("volumeMounts", []) if m["mountPath"] == "/tmp"}
    check(
        f"{n} writable /tmp",
        len(tmp) == 1 and all("emptyDir" in volumes.get(v, {}) for v in tmp),
    )

# 2. Certificate.
certs = res.get("certificates", {})
check("one Certificate", len(certs) == 1, sorted(certs))
for n, cert in certs.items():
    spec = cert["spec"]
    issuer = spec.get("issuerRef", {})
    check(f"{n} one URI SAN", spec.get("uris") == [IDENTITY], spec.get("uris"))
    check(
        f"{n} issuer",
        issuer.get("name") == ISSUER and issuer.get("kind") == "ClusterIssuer",
        issuer,
    )
    for f in (
        "dnsNames",
        "ipAddresses",
        "emailAddresses",
        "otherNames",
        "commonName",
        "literalSubject",
    ):
        check(f"{n} no {f}", not spec.get(f), spec.get(f))
    check(f"{n} not a CA", not spec.get("isCA"))
    usages = set(spec.get("usages", []))
    check(
        f"{n} usages",
        {"server auth", "client auth"}
        <= usages
        <= {"digital signature", "key encipherment", "server auth", "client auth"},
        sorted(usages),
    )

# 3. Egress.
policies = {
    **res.get("ciliumClusterwideNetworkPolicies", {}),
    **res.get("ciliumNetworkPolicies", {}),
}
check("one egress policy", len(policies) == 1, sorted(policies))
for n, p in policies.items():
    spec = p["spec"]
    sel = spec.get("endpointSelector", {})
    exprs = {
        (e["key"], e["operator"], tuple(e.get("values", [])))
        for e in sel.get("matchExpressions", [])
    }
    check(
        f"{n} selects {NS}/{SA} only",
        exprs == {(NS_KEY, "In", (NS,)), (SA_KEY, "In", (SA,))}
        and not sel.get("matchLabels"),
        sel,
    )
    check(f"{n} no ingress", not spec.get("ingress") and not spec.get("ingressDeny"))
    allowed = set()
    for rule in spec.get("egress", []):
        check(
            f"{n} rule is toCIDR only", set(rule) == {"toCIDR", "toPorts"}, sorted(rule)
        )
        for cidr in rule.get("toCIDR", []):
            for tp in rule.get("toPorts", []):
                check(f"{n} no L7 rules", "rules" not in tp)
                for port in tp.get("ports", []):
                    allowed.add((cidr, port.get("port"), port.get("protocol")))
    check(f"{n} egress", allowed == EGRESS, sorted(allowed))

# 4. The register socket sits on a volume mounted at the same path in both containers.
args = containers.get("xmsg", {}).get("args", [])
sock = (
    args[args.index("--leaf-register-sock") + 1]
    if "--leaf-register-sock" in args
    else None
)
principal = (
    args[args.index("--leaf-principal") + 1] if "--leaf-principal" in args else None
)
check("xmsg runs as a leaf", "--leaf" in args, args)
check("leaf principal is the bare service name", principal == SA, principal)
check("no retired svc: form", not any("svc:" in a for a in args), args)
check("no --host-label (xmsg refuses it)", "--host-label" not in args, args)

# 5. The hub entry: keyed by the hub's node name, and allowed to `list` this leaf.
hub = json.loads(res["configMaps"][f"{SA}-xmsg-peers"]["data"]["peers.json"])
check("one peer, the hub", set(hub) == {HUB}, sorted(hub))
check("hub may list", "list" in hub.get(HUB, {}).get("allow", []), hub.get(HUB))
check("register socket named", sock is not None)
if sock:

    def holder(c):
        return {
            (m["name"], m["mountPath"])
            for m in c.get("volumeMounts", [])
            if posixpath.dirname(posixpath.dirname(sock)) == m["mountPath"].rstrip("/")
        }

    shared = holder(containers["xmsg"]) & holder(containers.get(SA, {}))
    check("socket volume mounted in both containers", len(shared) == 1, sock)
    for v, mount in shared:
        check(
            "socket volume is an emptyDir",
            "emptyDir" in volumes.get(v, {}),
            volumes.get(v),
        )
        env = {e["name"]: e.get("value") for e in containers[SA].get("env", [])}
        check(
            "guard finds the socket",
            env.get("XDG_RUNTIME_DIR") == mount
            and f"{mount}/xmsg/register.sock" == sock,
            env.get("XDG_RUNTIME_DIR"),
        )

if failed:
    print("genie-guard-pod: FAILED", *failed, sep="\n  ")
    sys.exit(1)
print("genie-guard-pod: all properties hold")
