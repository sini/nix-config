# shellcheck shell=bash
# Usage: matrix-bot-provision '#support:json64.dev'
#        matrix-bot-provision --self-test
#
# One-shot: registers @genie on the in-cluster Synapse (shared-secret admin API,
# admin=false, throwaway password), encrypts its access token straight into the
# bitstream agenix secret, joins the room and prints the `rooms` setting line.
# Re-running after the token is saved skips registration and only joins.
# The token never reaches argv, stdout or an unencrypted file.
set -euo pipefail

bot=genie
server=json64.dev
namespace=matrix
target=.secrets/hosts/bitstream/matrix-genie-token.age
shared_secret_file=.secrets/env/prod/matrix-synapse/registration-shared-secret.age
local_port=${MATRIX_BOT_PROVISION_PORT:-18008}

# HMAC-SHA1(MAC_KEY, nonce \0 user \0 MAC_PASSWORD \0 notadmin), hex. Key and
# password come from the environment, never argv.
register_mac() {
  MAC_NONCE=$1 MAC_USER=$2 python3 -c '
import hashlib, hmac, os
e = os.environb
msg = b"\0".join([e[b"MAC_NONCE"], e[b"MAC_USER"], e[b"MAC_PASSWORD"], b"notadmin"])
print(hmac.new(e[b"MAC_KEY"], msg, hashlib.sha1).hexdigest())'
}

if [[ ${1:-} == --self-test ]]; then
  got=$(MAC_KEY=shared-secret MAC_PASSWORD=pw register_mac abcdef genie)
  want=$(printf 'abcdef\0genie\0pw\0notadmin' | openssl dgst -sha1 -hmac shared-secret -r | cut -d' ' -f1)
  [[ $got == "$want" ]] || {
    echo "register_mac: got $got, openssl says $want" >&2
    exit 1
  }
  echo "$got"
  exit 0
fi

alias_=${1:?usage: matrix-bot-provision '#support:json64.dev'}
[[ $alias_ == \#*:* ]] || {
  echo "expected a room alias like '#support:$server', got '$alias_'" >&2
  exit 1
}

cd "$(git rev-parse --show-toplevel)"
identity=$(mktemp)
pf_log=$(mktemp)
pf_pid=
cleanup() {
  [[ -n $pf_pid ]] && kill "$pf_pid" 2>/dev/null || true
  rm -f "$identity" "$pf_log"
}
trap cleanup EXIT

base=http://127.0.0.1:$local_port
token=

# GET/POST against Synapse; the bearer token (if any) goes in via a fd, not argv.
# Prints the body, then the HTTP status on its own last line.
api() {
  local method=$1 path=$2
  shift 2
  curl -sS -X "$method" -w '\n%{http_code}' \
    -H @<(printf 'Content-Type: application/json\n'; [[ -n $token ]] && printf 'Authorization: Bearer %s\n' "$token") \
    "$@" "$base$path"
}
body_of() { printf '%s' "$1" | sed '$d'; }
status_of() { printf '%s' "$1" | tail -n1; }

kubectl -n "$namespace" port-forward svc/synapse "$local_port:8008" >"$pf_log" 2>&1 &
pf_pid=$!
for _ in $(seq 30); do
  curl -sf -o /dev/null "$base/_matrix/client/versions" && break
  kill -0 "$pf_pid" 2>/dev/null || {
    cat "$pf_log" >&2
    exit 1
  }
  sleep 0.5
done
curl -sf -o /dev/null "$base/_matrix/client/versions" || {
  echo "synapse did not answer on $base" >&2
  exit 1
}

age-plugin-yubikey -i >"$identity"
[[ -s $identity ]] || { echo "matrix-bot-provision: no YubiKey identity found; plug in the YubiKey" >&2; exit 1; }

if [[ -e $target ]]; then
  echo "$target exists: skipping registration, joining with the saved token"
  token=$(age -d -i "$identity" "$target")
else
  MAC_KEY=$(age -d -i "$identity" "$shared_secret_file")
  MAC_PASSWORD=$(openssl rand -hex 32)
  export MAC_KEY MAC_PASSWORD

  resp=$(api GET /_synapse/admin/v1/register)
  [[ $(status_of "$resp") == 200 ]] || {
    body_of "$resp" >&2
    exit 1
  }
  nonce=$(body_of "$resp" | jq -er .nonce)
  mac=$(register_mac "$nonce" "$bot")

  resp=$(NONCE=$nonce USERNAME=$bot MAC=$mac jq -nc \
    '{nonce: env.NONCE, username: env.USERNAME, password: env.MAC_PASSWORD, admin: false, mac: env.MAC}' |
    api POST /_synapse/admin/v1/register --data-binary @-)
  unset MAC_KEY MAC_PASSWORD
  body=$(body_of "$resp")
  if [[ $(status_of "$resp") != 200 ]]; then
    errcode=$(printf '%s' "$body" | jq -r '.errcode // empty' 2>/dev/null || true)
    if [[ $errcode == M_USER_IN_USE ]]; then
      cat >&2 <<EOF
@$bot:$server already exists, and $target is absent, so its token is lost
(password login is disabled server-wide; nothing here can log it in).
Either restore $target from git history, or mint a token as a server admin:
  POST /_synapse/admin/v1/users/@$bot:$server/login   (admin access token)
and encrypt it to $target with the master recipients, then re-run this command
to join the room.
EOF
      exit 1
    fi
    printf '%s\n' "$body" >&2
    exit 1
  fi
  token=$(printf '%s' "$body" | jq -er .access_token)

  # Saved before anything else can fail, so a re-run only has to join.
  mapfile -t recipients < <(sed -n 's/^#[[:space:]]*Recipient:[[:space:]]*//p' .secrets/pub/master*.pub | sort -u)
  ((${#recipients[@]})) || {
    echo "no '# Recipient:' lines in .secrets/pub/master*.pub" >&2
    exit 1
  }
  rargs=()
  for r in "${recipients[@]}"; do rargs+=(-r "$r"); done
  printf '%s' "$token" | age "${rargs[@]}" -o "$target"
  git add "$target"
  echo "registered @$bot:$server; token encrypted to $target (staged)"
fi

enc_alias=$(printf '%s' "$alias_" | jq -sRr @uri)
resp=$(api GET "/_matrix/client/v3/directory/room/$enc_alias")
[[ $(status_of "$resp") == 200 ]] || {
  echo "could not resolve $alias_:" >&2
  body_of "$resp" >&2
  exit 1
}
room_id=$(body_of "$resp" | jq -er .room_id)

resp=$(api POST "/_matrix/client/v3/join/$(printf '%s' "$room_id" | jq -sRr @uri)" --data '{}')
[[ $(status_of "$resp") == 200 ]] || {
  echo "could not join $room_id:" >&2
  body_of "$resp" >&2
  exit 1
}

cat <<EOF
@$bot:$server joined $alias_ = $room_id

Set in modules/den/hosts/bitstream.nix, under den.hosts.x86_64-linux.bitstream.settings:
      services.matrix-xmsg.rooms = [ "$room_id" ];

Then: agenix rekey -a, commit, deploy bitstream.
EOF
