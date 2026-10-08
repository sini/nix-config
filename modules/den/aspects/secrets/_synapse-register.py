"""Register a non-admin Synapse user and print its access token.

Run inside the Synapse pod by the synapse-bot-token generator:
    kubectl exec -i ... -- python3 - USER SECRETS_YAML < _synapse-register.py
so registration_shared_secret is read from the pod's own config and never
leaves it. The password is throwaway: only the access token is kept.

    python3 _synapse-register.py --self-test   # MAC on a fixed vector
"""

import hashlib
import hmac
import json
import secrets
import sys
import urllib.error
import urllib.request


def register_mac(key: bytes, nonce: bytes, user: bytes, password: bytes) -> str:
    msg = b"\0".join([nonce, user, password, b"notadmin"])
    return hmac.new(key, msg, hashlib.sha1).hexdigest()


if sys.argv[1] == "--self-test":
    print(register_mac(b"shared-secret", b"abcdef", b"genie", b"pw"))
    sys.exit(0)

import yaml  # noqa: E402  (only present in the Synapse image)

user, secrets_file = sys.argv[1], sys.argv[2]
with open(secrets_file) as f:
    key = yaml.safe_load(f)["registration_shared_secret"].encode()

url = "http://localhost:8008/_synapse/admin/v1/register"
nonce = json.load(urllib.request.urlopen(url))["nonce"]
password = secrets.token_hex(32)
body = {
    "nonce": nonce,
    "username": user,
    "password": password,
    "admin": False,
    "mac": register_mac(key, nonce.encode(), user.encode(), password.encode()),
}
req = urllib.request.Request(
    url, data=json.dumps(body).encode(), headers={"Content-Type": "application/json"}
)
try:
    resp = json.load(urllib.request.urlopen(req))
except urllib.error.HTTPError as e:
    err = json.load(e)
    if err.get("errcode") == "M_USER_IN_USE":
        sys.exit(
            f"@{user} already exists and its token is lost (password login is "
            "disabled server-wide). Restore the secret from git history, or mint "
            f"a token as a server admin: POST /_synapse/admin/v1/users/@{user}:<server>/login"
        )
    sys.exit(f"register failed: {err}")
print(resp["access_token"])
