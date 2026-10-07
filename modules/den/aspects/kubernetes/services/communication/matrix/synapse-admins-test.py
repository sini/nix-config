# Runs synapse-admins.py against a fake Synapse admin API.
#   nix shell nixpkgs#python3 -c python3 synapse-admins-test.py
import base64
import hashlib
import hmac
import json
import os
import subprocess
import sys
import threading
import urllib.parse
from http.server import BaseHTTPRequestHandler, HTTPServer

REG, JWT, SELF = "reg-secret", "jwt-secret", "@synapse-admins:ex.org"
TOKEN = "tok-SECRET-VALUE"
users = {}  # user id -> admin flag
calls = []


def unb64(s):
    return base64.urlsafe_b64decode(s + "=" * (-len(s) % 4))


class Fake(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def reply(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def authed(self):
        if self.headers.get("Authorization") != "Bearer " + TOKEN or not users.get(
            SELF
        ):
            self.reply(403, {"errcode": "M_FORBIDDEN", "error": "not a server admin"})
            return False
        return True

    def body(self):
        return json.loads(
            self.rfile.read(int(self.headers.get("Content-Length", 0))) or b"{}"
        )

    def do_GET(self):
        u = urllib.parse.urlparse(self.path)
        if u.path == "/_synapse/admin/v1/register":
            return self.reply(200, {"nonce": "n1"})
        if not self.authed():
            return
        if u.path == "/_synapse/admin/v2/users":
            q = dict(urllib.parse.parse_qsl(u.query))
            assert q["admins"] == "true"
            names = sorted(n for n, a in users.items() if a)
            start = int(q["from"])
            page = names[start : start + 2]  # tiny pages exercise next_token
            r = {"users": [{"name": n} for n in page]}
            if start + 2 < len(names):
                r["next_token"] = str(start + 2)
            return self.reply(200, r)
        uid = urllib.parse.unquote(u.path.rsplit("/", 1)[1])
        if uid not in users:
            return self.reply(
                404, {"errcode": "M_NOT_FOUND", "error": "User not found"}
            )
        self.reply(200, {"name": uid, "admin": users[uid]})

    def do_POST(self):
        b = self.body()
        if self.path == "/_synapse/admin/v1/register":
            msg = b"\0".join(
                x.encode() for x in (b["nonce"], b["username"], b["password"], "admin")
            )
            assert b["mac"] == hmac.new(REG.encode(), msg, hashlib.sha1).hexdigest(), (
                "bad mac"
            )
            uid = f"@{b['username']}:ex.org"
            if uid in users:
                return self.reply(
                    400, {"errcode": "M_USER_IN_USE", "error": "User ID already taken."}
                )
            users[uid] = b["admin"]
            calls.append("register")
            return self.reply(200, {"access_token": TOKEN, "user_id": uid})
        if self.path == "/_matrix/client/v3/login":
            h, p, s = b["token"].split(".")
            want = hmac.new(JWT.encode(), f"{h}.{p}".encode(), hashlib.sha256).digest()
            claims = json.loads(unb64(p))
            if unb64(s) != want or claims["iss"] != "synapse-admins":
                return self.reply(
                    403, {"errcode": "M_FORBIDDEN", "error": "JWT validation failed"}
                )
            assert f"@{claims['sub']}:ex.org" in users, (
                "jwt login would create the user"
            )
            calls.append("login")
            return self.reply(200, {"access_token": TOKEN})
        if self.path == "/_matrix/client/v3/logout":
            calls.append("logout")
            return self.reply(200, {})
        self.reply(404, {})

    def do_PUT(self):
        if not self.authed():
            return
        uid = urllib.parse.unquote(self.path.rsplit("/", 1)[1])
        b = self.body()
        assert uid in users, f"PUT would create {uid}"
        assert b == {"admin": b["admin"]}, f"PUT touched more than admin: {b}"
        assert not (uid == SELF and not b["admin"]), "service account demoted"
        users[uid] = b["admin"]
        calls.append(f"put {uid} {b['admin']}")
        self.reply(200, {})


srv = HTTPServer(("127.0.0.1", 0), Fake)
threading.Thread(target=srv.serve_forever, daemon=True).start()
script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "synapse-admins.py")
env = dict(
    os.environ,
    SYNAPSE_URL=f"http://127.0.0.1:{srv.server_port}",
    SERVER_NAME="ex.org",
    SERVICE_LOCALPART="synapse-admins",
    JWT_ISSUER="synapse-admins",
    REGISTRATION_SHARED_SECRET=REG,
    JWT_SECRET=JWT,
    ADMINS=json.dumps(["@json:ex.org", "@new:ex.org", "@keep:ex.org"]),
)


def run(label):
    calls.clear()
    p = subprocess.run(
        [sys.executable, script], env=env, capture_output=True, text=True, check=False
    )
    print(f"--- {label}: rc={p.returncode}\n{p.stdout}{p.stderr}", end="")
    assert p.returncode == 0
    assert TOKEN not in p.stdout + p.stderr, "token leaked"
    return p.stdout


users.update(
    {
        "@json:ex.org": False,
        "@keep:ex.org": True,
        "@old:ex.org": True,
        "@x1:ex.org": True,
    }
)
out = run("first run (service account absent)")
assert calls[0] == "register" and calls[-1] == "logout", calls
assert "promote @json:ex.org" in out and "skip @new:ex.org: no account yet" in out
assert "demote @old:ex.org" in out and "demote @x1:ex.org" in out
assert (
    "@new:ex.org" not in users
    and users[SELF]
    and users["@json:ex.org"]
    and users["@keep:ex.org"]
)
assert not users["@old:ex.org"] and not users["@x1:ex.org"]

out = run("second run (service account exists, converged)")
assert calls == ["login", "logout"], calls
assert users[SELF]

users["@new:ex.org"] = False  # @new logs in for the first time
users["@old:ex.org"] = True  # someone re-promotes @old by hand
out = run("third run (drift)")
assert calls == ["login", "put @new:ex.org True", "put @old:ex.org False", "logout"], (
    calls
)

env["ADMINS"] = "[]"
calls.clear()
p = subprocess.run(
    [sys.executable, script], env=env, capture_output=True, text=True, check=False
)
print(f"--- empty admin set: rc={p.returncode}\n{p.stderr}", end="")
assert p.returncode != 0 and calls == [], calls

env["ADMINS"], env["JWT_SECRET"] = '["@json:ex.org"]', "wrong"
p = subprocess.run(
    [sys.executable, script], env=env, capture_output=True, text=True, check=False
)
print(f"--- bad jwt secret: rc={p.returncode}\n{p.stderr}", end="")
assert p.returncode != 0 and "M_FORBIDDEN" in p.stderr
print("PASS")
