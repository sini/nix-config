"""Property check over axon's rendered xmsg-gateway resources (the gateway's chart
and the objects around it): one uid on every container, pod hardening, the tunnel
sidecar, the owner configuration and bindings, the grant-store initContainers, secret
modes, the leaf certificate, the egress policy, and the public ingress (a Service,
routes that carry only discovery, /oauth and, with the AS, /mcp, and an ingress policy
that admits envoy alone).

Usage: xmsg-gateway-check.py <manifests.json>
  manifests.json: {"axon": <axon's resources>, "leaves": <the xmsg-leaves record>}
Exits non-zero, naming every failed property, when one does not hold.
"""

import json
import posixpath
import re
import sys

NS = SA = "xmsg-gateway"
UID = 10001
IDENTITY = f"spiffe://json64.dev/ns/{NS}/sa/{SA}"
ISSUER = "xmsg-cluster-ca"
UPLINK_DEV_IP = "10.10.11.1"
# axon's hub and extra hubs: each one's LAN address, federation port and identity.
HUBS = {
    "sini.cortex": ("10.9.2.1", "7788", "spiffe://json64.dev/host/cortex/user/sini"),
    "sini.bitstream": (
        "10.9.1.1",
        "7788",
        "spiffe://json64.dev/host/bitstream/user/sini",
    ),
    "sini.uplink-dev": (
        UPLINK_DEV_IP,
        "7788",
        "spiffe://json64.dev/host/uplink-dev/user/sini",
    ),
}
# Reached through cortex by forwarding, never peers (axon's relayed).
RELAYED = ["sini.patch", "sini.blade"]
# The first grant, and the AS's local one (axon has the AS on, Events on the local).
GRANT, LOCAL_GRANT = "chatgpt", "chatgpt-as"
HUB_RIGHTS = ["list", "reply", "send"]
# Each hub's federation port; public HTTPS for Events callbacks. kanidm is reached at
# the cluster gateway VIP, inside the cluster, so it needs no CIDR rule.
EGRESS = {
    *(("cidr", f"{ip}/32", port) for ip, port, _ in HUBS.values()),
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
# The gateway's migrations, in its order (serving.md "Repeatable migrations").
MIGRATIONS = [
    "migrate-custody",
    "migrate-outbound",
    "migrate-retirement",
    "migrate-custody-summaries",
    "migrate-events",
    "migrate-profiles",
    "migrate-attachments",
]
# The public ingress (xmsg-gateway.nix): what envoy may route, and from where. /mcp
# is route B, on with the authorization server.
PUBLIC_PATHS = {
    ("PathPrefix", "/.well-known/oauth-protected-resource"),
    ("Exact", "/.well-known/oauth-authorization-server"),
    ("PathPrefix", "/oauth"),
    ("PathPrefix", "/oauth/authorize"),
    ("PathPrefix", "/mcp"),
}
# The chart's selector labels (_helpers.tpl gw.selectorLabels).
POD_LABELS = {
    "app.kubernetes.io/name": "xmsg-mcp-gateway",
    "app.kubernetes.io/instance": SA,
}
INGRESS_POLICY = f"{SA}-ingress"


failed = []


def check(name, ok, detail=""):
    if not ok:
        failed.append(f"{name}: {detail}" if detail else name)


def arg_after(args, flag):
    return args[args.index(flag) + 1] if flag in args else None


with open(sys.argv[1]) as f:
    renders = json.load(f)

app = renders["axon"]["applications"][SA]
res = app["resources"]
check("namespace", app["namespace"] == NS, app.get("namespace"))
check("no Ingress object", not res.get("ingresses"))
# The Service exposes the listener's one port, and the routes carry only discovery,
# /oauth and /mcp: everything else on the host 404s at envoy.
svc_ports = [
    (p.get("port"), p.get("targetPort"))
    for p in res.get("services", {}).get(SA, {}).get("spec", {}).get("ports", [])
]
check("one Service port, the listener's", svc_ports == [(8787, "http")], svc_ports)
route_paths = {
    (m["path"]["type"], m["path"]["value"])
    for r in res.get("httpRoutes", {}).values()
    for rule in r["spec"]["rules"]
    for m in rule.get("matches", [])
}
check(
    "routes carry only the public OAuth paths",
    route_paths == PUBLIC_PATHS,
    sorted(route_paths),
)

dep = res["deployments"][SA]["spec"]
pod = dep["template"]["spec"]
containers = {c["name"]: c for c in pod["containers"]}
inits = pod.get("initContainers", [])
volumes = {v["name"]: v for v in pod.get("volumes", [])}

# 1. One Deployment, one replica, Recreate; the leaf, the gateway and the tunnel.
check("one replica", dep.get("replicas") == 1, dep.get("replicas"))
check(
    "Recreate", dep.get("strategy", {}).get("type") == "Recreate", dep.get("strategy")
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
binding = json.loads(cfg_files[f"binding-{GRANT}.json"])
gw = containers["gateway"]
config_path = arg_after(gw.get("args", []), "--config")
check("gateway serves its config", gw.get("args", [])[:1] == ["serve"], gw.get("args"))
for field in (
    "bind",
    "grant_store",
    "request_timeout_ms",
    "allowed_hosts",
    "allowed_origins",
    "verifier_profiles",
    "messaging",
    "events",
):
    check(f"serving.json has {field}", field in serving)
# The listener binds the pod network for envoy, which the gateway refuses without the
# explicit switch; the ingress policy (section 8) keeps every other peer out.
check(
    "bind is the pod network",
    serving.get("bind") == "0.0.0.0:8787",
    serving.get("bind"),
)
check(
    "non-loopback bind is explicit",
    serving.get("allow_non_loopback_bind") is True,
    serving.get("allow_non_loopback_bind"),
)
# The Kanidm profile, the first grant's verifier.
v = next(
    (p for p in serving.get("verifier_profiles", []) if not p.get("local")),
    {},
)
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
    "binding equals the Kanidm verifier profile",
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

# 5. Grant store: busybox prepare, then the chart's bootstrap, all on the real store:
# init --if-needed (a no-op on an existing store), the backup, every migration, enroll
# --if-needed each grant (exact binding, no rewrite), apply each grant. The AS adds its
# migration.
names = [c["name"] for c in inits]
migs = MIGRATIONS + ["migrate-authorization-server"]
ENROLLS = [f"store-enroll-{GRANT}", f"store-enroll-{LOCAL_GRANT}"]
APPLIES = [f"store-apply-{GRANT}", f"store-apply-{LOCAL_GRANT}"]
check(
    "initContainer order",
    names
    == ["prepare", "store-init", "store-backup"]
    + [f"store-{m}" for m in migs]
    + ENROLLS
    + APPLIES,
    names,
)
store = serving.get("grant_store")
for c in inits[1:]:
    args = c.get("args", [])
    check(f"{c['name']} uses the gateway image", c.get("image") == gw.get("image"))
    check(f"{c['name']} has no command override", "command" not in c)
    check(
        f"{c['name']} runs on the real store", arg_after(args, "--state") == store, args
    )
    step = c["name"].removeprefix("store-")
    if step.startswith("migrate-"):
        check(f"{c['name']} runs its step", args[2:3] == [step], args)
        check(f"{c['name']} has --if-needed", "--if-needed" in args, args)
init = next((c for c in inits if c["name"] == "store-init"), {})
check(
    "store-init has --if-needed",
    init.get("args") == ["--state", store, "init", "--if-needed"],
    init.get("args"),
)
# No scratch copy: the only store path any step names is the real one.
STORE_PATH = re.compile(r"/var/lib/xmsg-mcp-gateway/(?:state|staging)/[\w.-]+")
used = {
    p
    for c in inits
    for s in c.get("args", []) + c.get("command", [])
    for p in STORE_PATH.findall(s)
}
check(
    "no scratch copy",
    used <= {store}
    and not any("symlink" in s for c in inits for s in c.get("command", [])),
    sorted(used - {store}),
)
mig = next((c for c in inits if c["name"] == "store-migrate-events"), {})
check(
    "store-migrate-events uses the events key",
    arg_after(mig.get("args", []), "--key-file") == ev.get("key_file"),
)
for step, grant in zip(ENROLLS, (GRANT, LOCAL_GRANT)):
    enroll = next((c for c in inits if c["name"] == step), {})
    check(
        f"{step} has --if-needed",
        enroll.get("args", [])[2:]
        == [
            "enroll",
            grant,
            f"{posixpath.dirname(config_path)}/binding-{grant}.json",
            "--if-needed",
        ],
        enroll.get("args"),
    )
check(
    "Events on the local grant", ev.get("grant_id") == LOCAL_GRANT, ev.get("grant_id")
)

# 5a. The backup: the gateway's backup-if-pending (serving.md "Snapshot before a pending
# migration"), after init and before every migration of the real store, keeping the
# newest 3 (xmsg-design, 2026-11-13), into a directory on the data volume beside, not
# inside, the state directory.
bc = next((c for c in inits if c["name"] == "store-backup"), {})
bargs = bc.get("args", [])
bdir = arg_after(bargs, "--backup-dir") or ""
data = posixpath.dirname(posixpath.dirname(store or "/x/x"))
check("backup keeps the newest 3", arg_after(bargs, "--keep") == "3", bargs)
check(
    "backup is backup-if-pending beside the state directory",
    bargs[2:3] == ["backup-if-pending"]
    and posixpath.dirname(bdir) == data
    and bdir != posixpath.dirname(store or "")
    and set(mounts(bc).values()) == {"data"},
    (bargs, mounts(bc)),
)
check(
    "backup runs after init, before the real store's migrations",
    "store-backup" in names
    and names.index("store-init")
    < names.index("store-backup")
    < min(names.index(f"store-{m}") for m in MIGRATIONS if f"store-{m}" in names),
    names,
)

# 5b. The outbound policy, applied to the real store after install, per grant: every
# hub's sessions and the relayed nodes', for send and reply. No enablement flag, so
# apply keeps the grant's enablement.
check("apply step present", APPLIES[0] in names, names)
check("apply is last", names[-len(APPLIES) :] == APPLIES, names)
targets = [f"*@{h}" for h in HUBS] + [f"*@{n}" for n in RELAYED]
for grant, step in zip((GRANT, LOCAL_GRANT), APPLIES):
    apply = next((c for c in inits if c["name"] == step), None)
    aargs = (apply or {}).get("args", [])
    check(
        "apply has no --enabled",
        apply is not None and "--enabled" not in aargs and "--disabled" not in aargs,
        aargs,
    )
    check(
        f"{step} on the real store with policy-{grant}.json",
        aargs
        == [
            "--state",
            store,
            "apply",
            "--id",
            grant,
            "--policy",
            f"{posixpath.dirname(config_path)}/policy-{grant}.json",
        ]
        and (apply or {}).get("image") == gw.get("image")
        and "command" not in (apply or {}),
        aargs,
    )
    pol = json.loads(cfg_files.get(f"policy-{grant}.json", "{}"))
    check(
        f"policy-{grant}.json is every hub's sessions, send and reply",
        pol
        == {
            "send": {"targets": targets, "required_scope": "xmsg:send"},
            "reply": {"targets": targets, "required_scope": "xmsg:reply"},
        },
        pol,
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

peers = json.loads(res["configMaps"][f"{SA}-peers"]["data"]["peers.json"])["peers"]
check("one peer per hub", set(peers) == set(HUBS), sorted(peers))
for key, (ip, port, ident) in HUBS.items():
    p = peers.get(key, {})
    check(
        f"peer {key} CA-pinned at its address",
        p.get("address") == f"{ip}:{port}"
        and p.get("ca") == "/etc/xmsg/tls/ca.crt"
        and p.get("identities") == [ident]
        and "pin" not in p,
        p,
    )
    check(
        f"peer {key} rights", sorted(p.get("allow", [])) == HUB_RIGHTS, p.get("allow")
    )

# The xmsg-leaves record each hub turns into its peers entry for the leaf.
leaves = renders["leaves"]
check("one leaf record", len(leaves) == 1, leaves)
leaf = leaves[0] if leaves else {}
check(
    "leaf record names every hub",
    sorted(leaf.get("hubs", [])) == sorted(HUBS),
    leaf.get("hubs"),
)
check(
    "leaf record rights", sorted(leaf.get("allow", [])) == HUB_RIGHTS, leaf.get("allow")
)
check("leaf record identity", leaf.get("identity") == IDENTITY, leaf.get("identity"))
check(
    "leaf record targets every session",
    leaf.get("targets", 0) is None,
    leaf.get("targets"),
)

# 8. Network policy: one egress policy, and one ingress policy that admits only the
# envoy-gateway namespace, on the listener port.
ingress = res.get("ciliumNetworkPolicies", {}).get(INGRESS_POLICY, {}).get("spec", {})
check(
    "ingress policy selects the gateway pod",
    ingress.get("endpointSelector") == {"matchLabels": POD_LABELS},
    ingress.get("endpointSelector"),
)
ingress_from = [
    (
        [e.get("matchLabels") for e in r.get("fromEndpoints", [])],
        [
            (p.get("port"), p.get("protocol"))
            for tp in r.get("toPorts", [])
            for p in tp.get("ports", [])
        ],
        sorted(set(r) - {"fromEndpoints", "toPorts"}),
    )
    for r in ingress.get("ingress", [])
]
check(
    "ingress only from envoy-gateway, on the listener",
    ingress_from == [([{NS_KEY: "gateways"}], [("8787", "TCP")], [])],
    ingress_from,
)
check("ingress policy has no egress", not ingress.get("egress"))
policies = {
    **res.get("ciliumClusterwideNetworkPolicies", {}),
    **{
        k: v
        for k, v in res.get("ciliumNetworkPolicies", {}).items()
        if k != INGRESS_POLICY
    },
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

# 9. The tunnel sidecar, on the gateway's loopback listener.
on = containers
check(
    "tunnel sidecar present",
    set(on) == {"xmsg", "gateway", "tunnel-client"},
    sorted(on),
)
tenv = {e["name"]: e for e in on.get("tunnel-client", {}).get("env", [])}
check(
    "tunnel targets the loopback listener",
    tenv.get("MCP_SERVER_URL", {}).get("value") == "http://127.0.0.1:8787/mcp",
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
