# shellcheck shell=bash
# Usage: matrix-bot-provision '#support:json64.dev'
#
# Joins @genie to a room with its saved access token and prints the `rooms`
# setting line. The token itself comes from `agenix generate` (the
# synapse-bot-token generator). It never reaches argv, stdout or an
# unencrypted file.
set -euo pipefail

bot=genie
server=json64.dev
namespace=matrix
target=.secrets/hosts/bitstream/matrix-genie-token.age
local_port=${MATRIX_BOT_PROVISION_PORT:-18008}

# A public alias, or a room ID plus via servers for an invite-only room:
#   matrix-bot-provision '#support:json64.dev'
#   matrix-bot-provision '!roomid:matrix.org' matrix.org gitter.im
alias_=${1:?usage: matrix-bot-provision '#alias:server' | '!roomid[:server]' [via-server ...]}
shift
via=("$@")
[[ $alias_ == \#*:* || $alias_ == \!* ]] || {
  echo "expected a room alias like '#support:$server' or a room ID like '!abc:matrix.org', got '$alias_'" >&2
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

[[ -e $target ]] || {
  echo "$target is missing: run \`agenix generate\` to register @$bot and save its token" >&2
  exit 1
}
token=$(age -d -i "$identity" "$target")

if [[ $alias_ == \!* ]]; then
  room_id=$alias_
else
  enc_alias=$(printf '%s' "$alias_" | jq -sRr @uri)
  resp=$(api GET "/_matrix/client/v3/directory/room/$enc_alias")
  [[ $(status_of "$resp") == 200 ]] || {
    echo "could not resolve $alias_:" >&2
    body_of "$resp" >&2
    exit 1
  }
  room_id=$(body_of "$resp" | jq -er .room_id)
fi

# Via servers let a remote room (e.g. an invite) be joined by ID.
query=""
for v in "${via[@]}"; do
  query+="${query:+&}server_name=$(printf '%s' "$v" | jq -sRr @uri)"
done
resp=$(api POST "/_matrix/client/v3/join/$(printf '%s' "$room_id" | jq -sRr @uri)${query:+?$query}" --data '{}')
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
