"""Property check over xmsg-gateway.nix's manifests (flag forced on): one uid on
every container, pod hardening, no tunnel sidecar unless enabled, the owner
configuration and binding, the grant-store initContainers, secret modes, the leaf
certificate and the egress policy.

Usage: xmsg-gateway-check.py <manifests.json>
  manifests.json: {"off": <render, tunnel off>, "on": <render, tunnel on>}
Exits non-zero, naming every failed property, when one does not hold.
"""

import json
import os
import posixpath
import re
import sqlite3
import subprocess
import sys
import tempfile

NS = SA = "xmsg-gateway"
UID = 10001
IDENTITY = f"spiffe://json64.dev/ns/{NS}/sa/{SA}"
ISSUER = "xmsg-cluster-ca"
HUB = "sini.cortex"
# cortex's LAN address and its owner's federation port; uplink (kanidm) on 443;
# public HTTPS for Events callbacks.
EGRESS = {
    ("cidr", "10.9.2.1/32", "7788"),
    ("cidr", "10.10.10.1/32", "443"),
    ("entity", "world", "443"),
}
NS_KEY = "k8s:io.kubernetes.pod.namespace"
SA_KEY = "k8s:io.cilium.k8s.policy.serviceaccount"
VERIFIER = {
    "issuer": "https://idm.json64.dev/oauth2/openid/xmsg-gateway",
    "introspection_url": "https://idm.json64.dev/oauth2/token/introspect",
    "audience": "xmsg-gateway",
    "hosted_client": "xmsg-gateway",
    "introspection_client": "xmsg-gateway-lookup",
    "resource": "https://xmsg-gateway.json64.dev/mcp",
}
STORE_STEPS = [
    "init",
    "migrate-custody",
    "migrate-outbound",
    "retirement-inspect",
    "migrate-retirement",
    "migrate-events",
    "enroll",
]
# The store application_ids (gateway grants.rs).
LEGACY, RETIREMENT = 0x584D4757, 0x584D4752

failed = []


def check(name, ok, detail=""):
    if not ok:
        failed.append(f"{name}: {detail}" if detail else name)


def arg_after(args, flag):
    return args[args.index(flag) + 1] if flag in args else None


with open(sys.argv[1]) as f:
    renders = json.load(f)

app = renders["off"]["applications"][SA]
res = app["resources"]
check("namespace", app["namespace"] == NS, app.get("namespace"))
check(
    "no Service or ingress", not ({"services", "ingresses", "httpRoutes"} & res.keys())
)

dep = res["deployments"][SA]["spec"]
pod = dep["template"]["spec"]
containers = {c["name"]: c for c in pod["containers"]}
inits = pod.get("initContainers", [])
volumes = {v["name"]: v for v in pod.get("volumes", [])}

# 1. One Deployment, one replica, Recreate; no tunnel container when tunnel is off.
check("one replica", dep.get("replicas") == 1, dep.get("replicas"))
check(
    "Recreate", dep.get("strategy", {}).get("type") == "Recreate", dep.get("strategy")
)
check(
    "tunnel off: leaf and gateway only",
    set(containers) == {"xmsg", "gateway"},
    sorted(containers),
)
check(
    "tunnel off: no tunnel image anywhere",
    "tunnel-client" not in json.dumps(pod),
)
check("no runtimeClassName", "runtimeClassName" not in pod)
check("pod service account", pod.get("serviceAccountName") == SA)
check("pod token not automounted", pod.get("automountServiceAccountToken") is False)
check(
    "SA token not automounted",
    res["serviceAccounts"][SA].get("automountServiceAccountToken") is False,
)
psc = pod.get("securityContext", {})
check("pod runAsUser", psc.get("runAsUser") == UID, psc.get("runAsUser"))
check("pod fsGroup", psc.get("fsGroup") == UID, psc.get("fsGroup"))
check(
    "fsGroup never re-chmods the state dirs",
    psc.get("fsGroupChangePolicy") == "OnRootMismatch",
    psc.get("fsGroupChangePolicy"),
)

# 2. Hardening, and the same uid on every container (the leaf's is the daemon uid).
on_pod = renders["on"]["applications"][SA]["resources"]["deployments"][SA]["spec"][
    "template"
]["spec"]
for c in on_pod["containers"] + on_pod.get("initContainers", []):
    check(
        f"tunnel on: {c['name']} never runs enable",
        not re.search(
            r"\benable\b", " ".join(c.get("args", []) + c.get("command", []))
        ),
    )
for c in pod["containers"] + inits:
    n = c["name"]
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
    check(
        f"{n} never runs enable",
        not re.search(
            r"\benable\b", " ".join(c.get("args", []) + c.get("command", []))
        ),
    )

# 3. The owner configuration and the binding.
cfg_files = res["configMaps"][f"{SA}-config"]["data"]
serving = json.loads(cfg_files["serving.json"])
binding = json.loads(cfg_files["binding.json"])
gw = containers["gateway"]
config_path = arg_after(gw.get("args", []), "--config")
check("gateway serves its config", gw.get("args", [])[:1] == ["serve"], gw.get("args"))
for field in (
    "bind",
    "grant_store",
    "request_timeout_ms",
    "allowed_hosts",
    "allowed_origins",
    "verifier",
    "messaging",
    "events",
):
    check(f"serving.json has {field}", field in serving)
check(
    "bind is loopback",
    re.fullmatch(r"127\.\d+\.\d+\.\d+:\d+", serving.get("bind", "")) is not None,
    serving.get("bind"),
)
v = serving.get("verifier", {})
for k, want in VERIFIER.items():
    check(f"verifier.{k}", v.get(k) == want, v.get(k))
check(
    "verifier scopes",
    {"identity:read", "events:subscribe"} <= set(v.get("required_scopes", [])),
    v.get("required_scopes"),
)
check(
    "subject is a UUID",
    re.fullmatch(r"[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}", v.get("subject", ""))
    is not None,
    v.get("subject"),
)
check(
    "binding equals the verifier profile",
    binding
    == {
        "service": v.get("service"),
        "issuer": v.get("issuer"),
        "resource": v.get("resource"),
        "subject": v.get("subject"),
        "hosted_client": v.get("hosted_client"),
    },
    binding,
)
paths = [
    serving.get("grant_store"),
    v.get("client_secret_file"),
    serving.get("events", {}).get("key_file"),
    serving.get("messaging", {}).get("xmsg", {}).get("register_socket"),
    serving.get("messaging", {}).get("xmsg", {}).get("agent_socket"),
]
check(
    "every path absolute",
    all(isinstance(p, str) and p.startswith("/") for p in paths),
    paths,
)

vt = v.get("timeout_ms", 0)
ev = serving.get("events", {})
rt = serving.get("request_timeout_ms", 0)
check(
    "events dispatch budget",
    vt + 11000 <= ev.get("dispatch_timeout_ms", 0) <= 60000,
    ev.get("dispatch_timeout_ms"),
)
check("request budget", 2 * vt + 41000 <= rt <= 60000, rt)

# 4. Messaging: the leaf's uid and node, sockets on the shared emptyDir, and
# manifest values equal to the leaf's limits.
m = serving.get("messaging", {})
x = m.get("xmsg", {})
leaf = containers["xmsg"]
largs = leaf.get("args", [])
check("xmsg runs as a leaf", "--leaf" in largs, largs)
check(
    "leaf principal is the service",
    arg_after(largs, "--leaf-principal") == x.get("service"),
)
check("no retired svc: form", not any("svc:" in a for a in largs), largs)
check(
    "daemon uid is the leaf's uid",
    x.get("daemon_uid") == leaf["securityContext"]["runAsUser"] == UID,
    x.get("daemon_uid"),
)
check(
    "expected node is <sa>.<ns>",
    x.get("expected_node") == f"{SA}.{NS}",
    x.get("expected_node"),
)
check(
    "register socket is the leaf's",
    x.get("register_socket") == arg_after(largs, "--leaf-register-sock"),
    x.get("register_socket"),
)
check(
    "agent socket is the leaf's",
    x.get("agent_socket") == arg_after(largs, "--agent-sock"),
    x.get("agent_socket"),
)
man = m.get("manifest", {})
for field, flag in (
    ("reply_ttl_secs", "--reply-ttl"),
    ("idempotency_ttl_secs", "--idempotency-ttl"),
    ("svc_queue_cap", "--svc-queue-cap"),
):
    check(
        f"manifest {field} equals the leaf's {flag}",
        str(man.get(field)) == arg_after(largs, flag),
    )
check(
    "framed bound fits the leaf's --max-body",
    0
    < man.get("max_framed_bytes", 0)
    <= min(65536, int(arg_after(largs, "--max-body") or 0)),
)
check(
    "dedup lifetime within the idempotency TTL",
    0 < man.get("dedup_lifetime_secs", 0) <= man.get("idempotency_ttl_secs", 0),
)


def mounts(c):
    return {m["mountPath"]: m["name"] for m in c.get("volumeMounts", [])}


sock_dir = posixpath.dirname(posixpath.dirname(x.get("register_socket", "/x/x")))
shared = mounts(leaf).get(sock_dir)
check(
    "socket volume shared by leaf and gateway",
    shared is not None and mounts(gw).get(sock_dir) == shared,
    sock_dir,
)
check("socket volume is an emptyDir", "emptyDir" in volumes.get(shared, {}), shared)

# 5. Grant store: busybox prepare, the five steps on the staged store, then an install
# that moves it into place only when the real store is absent.
names = [c["name"] for c in inits]
check(
    "initContainer order",
    names == ["prepare"] + [f"store-{s}" for s in STORE_STEPS] + ["store-install"],
    names,
)
store = serving.get("grant_store")
staged = None
for c in inits:
    if c["name"] in ("store-install", "store-retirement-inspect") or not c[
        "name"
    ].startswith("store-"):
        continue
    args = c.get("args", [])
    check(f"{c['name']} uses the gateway image", c.get("image") == gw.get("image"))
    check(f"{c['name']} has no command override", "command" not in c)
    if c["name"] != "store-migrate-retirement":
        staged = staged or arg_after(args, "--state")
        check(
            f"{c['name']} runs on the staged store",
            arg_after(args, "--state") == staged,
        )
    check(
        f"{c['name']} runs its step",
        args[2:3] == [c["name"].removeprefix("store-")],
        args,
    )
check("staged store is not the real one", staged and staged != store, staged)

# 5a. Retirement: inspect, then the one migrate-retirement on the link inspect made.
# The inspect script is run against fixture stores, so the backup's condition and its
# ordering before the link to the real store are behaviour, not text.
retire = next((c for c in inits if c["name"] == "store-migrate-retirement"), {})
link = arg_after(retire.get("args", []), "--state")
check(
    "migrate-retirement runs on a link in the staging directory",
    link
    and staged
    and posixpath.dirname(link) == posixpath.dirname(staged)
    and link not in (staged, store),
    link,
)
runs = [
    c["name"]
    for p in (pod, on_pod)
    for c in p["containers"] + p.get("initContainers", [])
    if "migrate-retirement" in c.get("args", []) + c.get("command", [])
]
check(
    "migrate-retirement runs exactly once per pod",
    runs == ["store-migrate-retirement"] * 2,
    runs,
)
check(
    "inspect runs before migrate-retirement",
    "store-retirement-inspect" in names
    and "store-migrate-retirement" in names
    and names.index("store-retirement-inspect")
    == names.index("store-migrate-retirement") - 1,
    names,
)
inspect = next((c for c in inits if c["name"] == "store-retirement-inspect"), {})
inspect_cmd = inspect.get("command", [])
check(
    "inspect is python on the data volume only",
    inspect_cmd[:3] == ["python3", "-I", "-c"]
    and set(mounts(inspect).values()) == {"data"},
    inspect_cmd[:3],
)


def make_store(path, app):
    db = sqlite3.connect(path)
    db.execute(f"PRAGMA application_id = {app}")
    db.execute("CREATE TABLE grants(id TEXT)")
    db.execute("INSERT INTO grants VALUES ('fixture')")
    db.commit()
    db.close()


def run_inspect(app, sealed=False):
    """Run the inspect script with the data directory moved under a temp dir; sealed
    makes the data directory itself unwritable, so a backup there cannot be made.
    Returns (exit code, link target, [(partial, group/other mode bits, marker, rows)])."""
    data = posixpath.dirname(posixpath.dirname(store))
    with tempfile.TemporaryDirectory() as tmp:
        root = tmp + data
        for d in (posixpath.dirname(store), posixpath.dirname(staged)):
            os.makedirs(root + d.removeprefix(data), exist_ok=True)
        make_store(root + staged.removeprefix(data), LEGACY)
        if app is not None:
            make_store(root + store.removeprefix(data), app)
        script = inspect_cmd[3].replace(data, root) if len(inspect_cmd) > 3 else ""
        if sealed:
            os.chmod(root, 0o555)
        code = subprocess.run(
            [sys.executable, "-I", "-c", script], capture_output=True, check=False
        ).returncode
        os.chmod(root, 0o755)
        lk = root + link.removeprefix(data) if link else ""
        target = (
            data + os.readlink(lk).removeprefix(root) if os.path.islink(lk) else None
        )
        backups = []
        for dirpath, _, files in os.walk(root):
            for f in files:
                p = posixpath.join(dirpath, f)
                if "pre-retirement" in f:
                    b = sqlite3.connect(p)
                    marker = b.execute("PRAGMA application_id").fetchone()[0]
                    rows = b.execute("SELECT id FROM grants").fetchall()
                    b.close()
                    backups.append(
                        (
                            f.endswith(".partial"),
                            os.stat(p).st_mode & 0o077,
                            marker,
                            rows,
                        )
                    )
        return code, target, backups


if staged and store and link:
    code, target, backups = run_inspect(None)
    check(
        "inspect, no store: link to the staged store, no backup",
        (code, target, backups) == (0, staged, []),
        (code, target, backups),
    )
    code, target, backups = run_inspect(RETIREMENT)
    check(
        "inspect, migrated store: link to the staged store, no backup",
        (code, target, backups) == (0, staged, []),
        (code, target, backups),
    )
    code, target, backups = run_inspect(LEGACY)
    check(
        "inspect, legacy store: one owner-private legacy backup, then link to the real store",
        (code, target, backups) == (0, store, [(False, 0, LEGACY, [("fixture",)])]),
        (code, target, backups),
    )
    code, target, backups = run_inspect(LEGACY, sealed=True)
    check(
        "inspect, legacy store, backup impossible: refuses, no link to the real store",
        code != 0 and target is None,
        (code, target, backups),
    )
    code, target, backups = run_inspect(0x1234)
    check(
        "inspect, unknown store: refuses, no link",
        code != 0 and target is None,
        (code, target, backups),
    )
enroll = next((c for c in inits if c["name"] == "store-enroll"), {})
check(
    "enroll uses the events grant and the binding",
    enroll.get("args", [])[3:]
    == [ev.get("grant_id"), f"{posixpath.dirname(config_path)}/binding.json"],
    enroll.get("args"),
)
mig = next((c for c in inits if c["name"] == "store-migrate-events"), {})
check(
    "migrate-events uses the events key",
    arg_after(mig.get("args", []), "--key-file") == ev.get("key_file"),
)
install = next((c for c in inits if c["name"] == "store-install"), {})
script = " ".join(install.get("command", []))
check(
    "install moves the staged store only if the real one is absent",
    f"if [ -e {store} ]" in script and f"mv {staged} {store}" in script,
    script,
)

# 6. Secrets: copied owner-private by prepare; the raw Secret volume only in prepare.
prep = " ".join(inits[0].get("command", [])) if inits else ""
lookup = v.get("client_secret_file")
key = ev.get("key_file")
check("lookup secret 0400", f"chmod 0400 {lookup}" in prep, prep)
# The gateway requires exactly 0600 for the Events key (event_store.rs EventKey::load).
check("events key 0600", f"chmod 0600 {key}" in prep, prep)
check(
    "key directory is 0700",
    f"{posixpath.dirname(key)}" in prep.split("chmod 0700", 1)[-1].split("\n", 1)[0],
)
for c in pod["containers"] + inits[1:]:
    check(
        f"{c['name']} does not mount the raw Secret",
        "secrets" not in mounts(c).values(),
    )
cm_mode = volumes.get("config", {}).get("configMap", {}).get("defaultMode", 0o644)
check("config not group- or world-writable", cm_mode & 0o022 == 0, oct(cm_mode))
sec_mode = volumes.get("secrets", {}).get("secret", {}).get("defaultMode", 0o644)
check("raw Secret not world-readable", sec_mode & 0o007 == 0, oct(sec_mode))
check(
    "state on the PVC",
    "persistentVolumeClaim"
    in volumes.get(mounts(gw).get(posixpath.dirname(posixpath.dirname(store))), {}),
)
check("PVC declared", SA in res.get("persistentVolumeClaims", {}))

# 7. Certificate.
certs = res.get("certificates", {})
check("one Certificate", len(certs) == 1, sorted(certs))
for n, cert in certs.items():
    spec = cert["spec"]
    iss = spec.get("issuerRef", {})
    check(f"{n} one URI SAN", spec.get("uris") == [IDENTITY], spec.get("uris"))
    check(
        f"{n} issuer",
        iss.get("name") == ISSUER and iss.get("kind") == "ClusterIssuer",
        iss,
    )
    for fld in (
        "dnsNames",
        "ipAddresses",
        "emailAddresses",
        "commonName",
        "literalSubject",
    ):
        check(f"{n} no {fld}", not spec.get(fld), spec.get(fld))
    check(f"{n} not a CA", not spec.get("isCA"))

hub = json.loads(res["configMaps"][f"{SA}-xmsg-peers"]["data"]["peers.json"])
check("one peer, the hub", set(hub) == {HUB}, sorted(hub))
check("hub may list", "list" in hub.get(HUB, {}).get("allow", []), hub.get(HUB))

# 8. Egress.
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
        kinds = set(rule) - {"toPorts"}
        check(f"{n} rule kind", kinds in ({"toCIDR"}, {"toEntities"}), sorted(rule))
        dests = [("cidr", d) for d in rule.get("toCIDR", [])] + [
            ("entity", d) for d in rule.get("toEntities", [])
        ]
        for kind, d in dests:
            for tp in rule.get("toPorts", []):
                check(f"{n} no L7 rules", "rules" not in tp)
                for port in tp.get("ports", []):
                    check(f"{n} TCP only", port.get("protocol") == "TCP")
                    allowed.add((kind, d, port.get("port")))
    check(f"{n} egress", allowed == EGRESS, sorted(allowed))

# 9. Tunnel on: the sidecar appears, on the gateway's loopback listener.
on = {c["name"]: c for c in on_pod["containers"]}
check(
    "tunnel on: sidecar present",
    set(on) == {"xmsg", "gateway", "tunnel-client"},
    sorted(on),
)
tenv = {e["name"]: e for e in on.get("tunnel-client", {}).get("env", [])}
check(
    "tunnel targets the loopback listener",
    tenv.get("MCP_SERVER_URL", {}).get("value") == f"http://{serving.get('bind')}/mcp",
    tenv.get("MCP_SERVER_URL"),
)
check(
    "tunnel key from the Secret",
    tenv.get("CONTROL_PLANE_API_KEY", {}).get("valueFrom", {}).get("secretKeyRef")
    == {"name": SA, "key": "tunnel-runtime-key"},
)

if failed:
    print("xmsg-gateway-pod: FAILED", *failed, sep="\n  ")
    sys.exit(1)
print("xmsg-gateway-pod: all properties hold")
