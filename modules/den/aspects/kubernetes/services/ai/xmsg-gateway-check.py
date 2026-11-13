"""Property check over xmsg-gateway.nix's manifests (flag forced on): one uid on
every container, pod hardening, no tunnel sidecar unless enabled, the owner
configuration and binding, the grant-store initContainers, secret modes, the leaf
certificate, the egress policy, and the public OAuth ingress (a Service, routes that
carry only discovery and /oauth, and an ingress policy that admits envoy alone).

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
# The hub and the extra hub: each one's LAN address, federation port and identity.
HUBS = {
    "sini.cortex": ("10.9.2.1", "7788", "spiffe://json64.dev/host/cortex/user/sini"),
    "sini.bitstream": (
        "10.9.1.1",
        "7788",
        "spiffe://json64.dev/host/bitstream/user/sini",
    ),
}
HUB_RIGHTS = ["list", "reply", "send"]
# Each hub's federation port; uplink (kanidm) on 443; public HTTPS for Events callbacks.
EGRESS = {
    *(("cidr", f"{ip}/32", port) for ip, port, _ in HUBS.values()),
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
# The public OAuth ingress (xmsg-gateway.nix): what envoy may route, and from where.
PUBLIC_PATHS = {
    ("PathPrefix", "/.well-known/oauth-protected-resource"),
    ("Exact", "/.well-known/oauth-authorization-server"),
    ("PathPrefix", "/oauth"),
    ("PathPrefix", "/oauth/authorize"),
}
INGRESS_POLICY = f"{SA}-ingress"
# The store application_ids (gateway grants.rs).
LEGACY, RETIREMENT, SUMMARY = 0x584D4757, 0x584D4752, 0x584D4753


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
check("no Ingress object", "ingresses" not in res)
# The Service exposes the listener's one port, and the routes carry only discovery
# and /oauth: everything else on the host, /mcp included, 404s at envoy.
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
check(
    "no route to /mcp",
    not any(v.startswith("/mcp") for _, v in route_paths),
    sorted(route_paths),
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

# 5. Grant store: busybox prepare; the fresh store built on the staged store (init,
# every migration, enroll); an install that moves it into place only when the real
# store is absent; a backup only when a migration will run; every migration on the
# real store; apply.
names = [c["name"] for c in inits]
check(
    "initContainer order",
    names
    == ["prepare", "staged-init"]
    + [f"staged-{m}" for m in MIGRATIONS]
    + ["staged-enroll", "store-install", "store-backup"]
    + [f"store-{m}" for m in MIGRATIONS]
    + ["store-apply"],
    names,
)
store = serving.get("grant_store")
staged = arg_after(
    next((c for c in inits if c["name"] == "staged-init"), {}).get("args", []),
    "--state",
)
check("staged store is not the real one", staged and staged != store, staged)
for c in inits:
    prefix, _, step = c["name"].partition("-")
    if prefix not in ("staged", "store") or step in ("install", "backup"):
        continue
    args = c.get("args", [])
    check(f"{c['name']} uses the gateway image", c.get("image") == gw.get("image"))
    check(f"{c['name']} has no command override", "command" not in c)
    check(
        f"{c['name']} runs on the {'staged' if prefix == 'staged' else 'real'} store",
        arg_after(args, "--state") == (staged if prefix == "staged" else store),
        args,
    )
    check(f"{c['name']} runs its step", args[2:3] == [step], args)
    if step.startswith("migrate-"):
        check(f"{c['name']} has --if-needed", "--if-needed" in args, args)
# No scratch copy: the only store paths any step names are the staged and the real
# (and the real store's rollback journal, which store-backup recovers when hot).
STORE_PATH = re.compile(r"/var/lib/xmsg-mcp-gateway/(?:state|staging)/[\w.-]+")
used = {
    p
    for c in inits
    for s in c.get("args", []) + c.get("command", [])
    for p in STORE_PATH.findall(s)
}
check(
    "no scratch copy",
    used <= {staged, store, f"{store}-journal"}
    and not any("symlink" in s for c in inits for s in c.get("command", [])),
    sorted(used - {staged, store, f"{store}-journal"}),
)
for prefix in ("staged", "store"):
    mig = next((c for c in inits if c["name"] == f"{prefix}-migrate-events"), {})
    check(
        f"{prefix}-migrate-events uses the events key",
        arg_after(mig.get("args", []), "--key-file") == ev.get("key_file"),
    )
enroll = next((c for c in inits if c["name"] == "staged-enroll"), {})
check(
    "enroll uses the events grant and the binding",
    enroll.get("args", [])[3:]
    == [ev.get("grant_id"), f"{posixpath.dirname(config_path)}/binding.json"],
    enroll.get("args"),
)
install = next((c for c in inits if c["name"] == "store-install"), {})
script = " ".join(install.get("command", []))
check(
    "install moves the staged store only if the real one is absent",
    f"if [ -e {store} ]" in script and f"mv {staged} {store}" in script,
    script,
)

# 5a. The backup: python on the data volume and the gateway image, after install and
# before every migration of the real store. The decision is the gateway's
# migrations-pending (serving.md "Inspect pending migrations": exit 0 none pending, 10
# pending, anything else an error). Its script is run against fixture stores with a stub
# gateway that exits as told, so the decision is behaviour, not text: each fixture's
# shape contradicts the stub's exit, so a copy of the done-rules decides wrongly.
bc = next((c for c in inits if c["name"] == "store-backup"), {})
bmounts = {m["mountPath"]: m for m in bc.get("volumeMounts", [])}
image_vol = volumes.get(bmounts.get("/nix", {}).get("name"), {})
bin_dir = next(
    (
        p
        for p, m in bmounts.items()
        if m.get("subPath") == "bin" and m["name"] == image_vol.get("name")
    ),
    None,
)
check(
    "backup is python on the data volume and the gateway image",
    bc.get("command", [])[:3] == ["python3", "-I", "-c"]
    and set(mounts(bc).values()) == {"data", image_vol.get("name")}
    and image_vol.get("image", {}).get("reference") == gw.get("image")
    and bmounts.get("/nix", {}).get("subPath") == "nix"
    and all(m.get("readOnly") for m in bmounts.values() if m["name"] != "data")
    and bin_dir is not None,
    (bc.get("command", [])[:3], bmounts),
)
check(
    "backup runs after install, before the real store's migrations",
    "store-backup" in names
    and names.index("store-install")
    < names.index("store-backup")
    < min(names.index(f"store-{m}") for m in MIGRATIONS if f"store-{m}" in names),
    names,
)
# The done-rules' inputs: none may reach the decision again.
script_text = " ".join(bc.get("command", []))
check(
    "backup decision is migrations-pending, no probe copy",
    f'"{bin_dir}/xmsg-mcp-gateway", "--state", "{store}", "migrations-pending"'
    in script_text
    and not re.search(
        r"user_version|sqlite_master|table_info|recovery_until|outbound_retire|0x584d47",
        script_text,
        re.IGNORECASE,
    ),
    script_text,
)

RETIREMENT_TABLES = (
    "outbound_retirement_schema",
    "outbound_request_fences",
    "outbound_retired",
    "outbound_retirement_clock",
)


def make_store(path, app, version, retired):
    """A fixture store with the markers the gateway's migration_applied reads."""
    db = sqlite3.connect(path)
    db.execute(f"PRAGMA application_id = {app}")
    db.execute(f"PRAGMA user_version = {version}")
    db.execute("CREATE TABLE grants(id TEXT)")
    db.execute("INSERT INTO grants VALUES ('fixture')")
    if version >= 3:
        cols = "owner TEXT" + (", recovery_until INTEGER" if retired else "")
        db.execute(f"CREATE TABLE outbound_reservations({cols})")
    for t in RETIREMENT_TABLES if retired else ():
        db.execute(f"CREATE TABLE {t}(x)")
    db.commit()
    db.close()


def run_backup(store_shape, exit_code, sealed=False):
    """Run the backup script with the data directory moved under a temp dir and a stub
    gateway exiting exit_code (printing one pending command on 10). sealed makes the
    data directory unwritable, so no backup can be made there.
    Returns (exit code, stub argv, [(partial, group/other mode bits, marker, rows)])."""
    cmd = bc.get("command", [])
    data = posixpath.dirname(posixpath.dirname(store))
    with tempfile.TemporaryDirectory() as tmp:
        root = tmp + data
        os.makedirs(root + posixpath.dirname(store).removeprefix(data))
        if store_shape:
            make_store(root + store.removeprefix(data), *store_shape)
        stub, argv_file = tmp + "/gateway", tmp + "/argv"
        with open(stub, "w") as f:
            f.write(
                f"#!{sys.executable} -I\nimport json, sys\n"
                f"json.dump(sys.argv[1:], open({argv_file!r}, 'w'))\n"
                f"print('migrate-custody-summaries' if {exit_code} == 10 else '', end='')\n"
                f"sys.exit({exit_code})\n"
            )
        os.chmod(stub, 0o755)
        script = (
            cmd[3].replace(f"{bin_dir}/xmsg-mcp-gateway", stub).replace(data, root)
            if len(cmd) > 3
            else ""
        )
        if sealed:
            os.chmod(root, 0o555)
        code = subprocess.run(
            [sys.executable, "-I", "-c", script], capture_output=True, check=False
        ).returncode
        os.chmod(root, 0o755)
        argv = None
        if os.path.exists(argv_file):
            with open(argv_file) as f:
                argv = [a.replace(root, data) for a in json.load(f)]
        backups = []
        for dirpath, _, files in os.walk(root):
            for f in files:
                if "pre-migrate-" in f:
                    p = posixpath.join(dirpath, f)
                    b = sqlite3.connect(p)
                    backups.append(
                        (
                            f.endswith(".partial"),
                            os.stat(p).st_mode & 0o077,
                            b.execute("PRAGMA application_id").fetchone()[0],
                            b.execute("SELECT id FROM grants").fetchall(),
                        )
                    )
                    b.close()
        return code, argv, backups


ROWS = [("fixture",)]
MIGRATED, UNMIGRATED = (SUMMARY, 4, True), (RETIREMENT, 4, True)
if store and bin_dir and len(bc.get("command", [])) > 3:
    code, argv, backups = run_backup(UNMIGRATED, 0)
    check(
        "backup, exit 0: no backup",
        (code, backups) == (0, []),
        (code, backups),
    )
    check(
        "backup runs migrations-pending on the real store",
        argv == ["--state", store, "migrations-pending"],
        argv,
    )
    code, _, backups = run_backup(MIGRATED, 10)
    check(
        "backup, exit 10: one owner-private backup",
        (code, backups) == (0, [(False, 0, SUMMARY, ROWS)]),
        (code, backups),
    )
    # 1 is the gateway's error exit (missing, corrupt, unsupported); 2 a usage error.
    for unknown in (1, 2, 3, 11, 137):
        code, _, backups = run_backup(MIGRATED, unknown)
        check(
            "backup, any other exit: refuses, no backup",
            code != 0 and backups == [],
            (unknown, code, backups),
        )
    code, _, backups = run_backup(UNMIGRATED, 10, sealed=True)
    check(
        "backup, backup impossible: refuses",
        code != 0 and all(p for p, *_ in backups),
        (code, backups),
    )

# 5b. The outbound policy, applied to the real store after install: every hub's sessions
# for send and reply, in the gateway's field order. No enablement flag, so apply keeps
# the grant's enablement.
apply = next((c for c in inits if c["name"] == "store-apply"), None)
check("apply step present", apply is not None, names)
aargs = (apply or {}).get("args", [])
check(
    "apply is last",
    apply is not None and names[-1] == "store-apply",
    names,
)
check(
    "apply has no --enabled",
    apply is not None and "--enabled" not in aargs and "--disabled" not in aargs,
    aargs,
)
check(
    "apply on the real store with policy.json",
    aargs
    == [
        "--state",
        store,
        "apply",
        "--id",
        ev.get("grant_id"),
        "--policy",
        f"{posixpath.dirname(config_path)}/policy.json",
    ]
    and (apply or {}).get("image") == gw.get("image")
    and "command" not in (apply or {}),
    aargs,
)
targets = json.dumps([f"*@{h}" for h in HUBS], separators=(",", ":"))
check(
    "policy.json is every hub's sessions, send and reply",
    cfg_files.get("policy.json")
    == f'{{"send":{{"targets":{targets},"required_scope":"xmsg:send"}},'
    f'"reply":{{"targets":{targets},"required_scope":"xmsg:reply"}}}}',
    cfg_files.get("policy.json"),
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

peers = json.loads(res["configMaps"][f"{SA}-xmsg-peers"]["data"]["peers.json"])
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
    ingress.get("endpointSelector") == {"matchLabels": {"app.kubernetes.io/name": SA}},
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
