#!/usr/bin/env bash
# Idempotency test for the nixidy Rule 2 render logic (the per-SopsSecret
# render script run inside an env's activationPackage).
#
# The nixidy-sync command itself just runs each env's `activate` entrypoint;
# the interesting, fragile behavior lives in the render scripts that activate
# invokes. Those scripts:
#   1. resolve the staged SopsSecret with `vals eval`,
#   2. hash the resolved plaintext (sha256),
#   3. if the existing target already carries that hash in the
#      `secrets.json64.dev/plaintext-sha256` annotation, emit the target
#      verbatim (NO re-encryption — this is what makes the sync idempotent),
#   4. otherwise re-encrypt with sops and stamp the new hash.
#
# This test reproduces that logic with stubbed `vals`, `sops`, `yq`, and
# `sha256sum`/`cut` so it needs no yubikey and is deterministic. It asserts:
#   - matching hash            -> output byte-identical to target, no encrypt
#   - mutated plaintext        -> hash differs, re-encrypt path taken
#   - encrypted annotations    -> read yields "" -> fail-closed re-encrypt
set -euo pipefail

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

BIN="$WORK/bin"
mkdir -p "$BIN"

# --- Stub PATH tools -------------------------------------------------------

# vals: cat stdin -> deterministic "resolved" output (identity passthrough).
cat > "$BIN/vals" <<'EOF'
#!/usr/bin/env bash
# Usage in render: `vals eval` reads the source SopsSecret on stdin? No --
# the real render does `vals eval` with the source provided via env; here we
# model resolution as identity over the staged file fed on stdin.
cat
EOF

# sops: deterministic fake-encrypt -- prefix a marker and base64 the body so
# the output is non-identical to plaintext but reproducible.
cat > "$BIN/sops" <<'EOF'
#!/usr/bin/env bash
# Ignore all flags; read the file to encrypt from the last argument or stdin.
src="/dev/stdin"
for a in "$@"; do :; done
# real invocation ends with `-e /dev/stdin`; just read stdin.
printf 'SOPS-ENC:'
base64 -w0 < "$src"
printf '\n'
EOF

# yq: minimal shim for the two operations the render uses.
#   read:  yq -r '.metadata.annotations["secrets.json64.dev/plaintext-sha256"] // ""' FILE
#   write: yq '.metadata.annotations."secrets.json64.dev/plaintext-sha256" = "SHA"'   (filter on stdin)
# We encode the annotation in a fixture as a line:  #PLAINTEXT-SHA256: <hash>
# Encrypted fixtures omit that line, so the read returns "".
cat > "$BIN/yq" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "-r" ]; then
  # read annotation from FILE (last arg)
  file="${!#}"
  if [ -f "$file" ] && grep -q '^#PLAINTEXT-SHA256: ' "$file"; then
    grep '^#PLAINTEXT-SHA256: ' "$file" | head -n1 | sed 's/^#PLAINTEXT-SHA256: //'
  else
    printf ''
  fi
  exit 0
fi
# write filter: extract the SHA being assigned, stamp it onto stdin body.
expr="$1"
sha="$(printf '%s' "$expr" | sed -n 's/.*= "\(.*\)"$/\1/p')"
printf '#PLAINTEXT-SHA256: %s\n' "$sha"
cat
EOF

chmod +x "$BIN"/*
export PATH="$BIN:$PATH"

# --- Render logic under test (mirror of the nixidy render script) ----------
# Reads the staged source on stdin, target path in TARGET_PATH.
render() {
  local resolved sha prev
  resolved="$(vals eval)"
  sha="$(printf '%s' "$resolved" | sha256sum | cut -d' ' -f1)"
  if [ -f "$TARGET_PATH" ]; then
    prev="$(yq -r '.metadata.annotations["secrets.json64.dev/plaintext-sha256"] // ""' "$TARGET_PATH")"
    if [ "$prev" = "$sha" ]; then
      cat "$TARGET_PATH"
      return 0
    fi
  fi
  printf '%s' "$resolved" \
    | yq '.metadata.annotations."secrets.json64.dev/plaintext-sha256" = "'"$sha"'"' \
    | sops --config /dev/null --filename-override "$TARGET_PATH" \
           --input-type yaml --output-type yaml -e /dev/stdin
}

fail() { echo "FAIL: $1" >&2; exit 1; }

PLAINTEXT='apiVersion: v1
kind: SopsSecret
plaintext: hunter2'

SHA="$(printf '%s' "$PLAINTEXT" | sha256sum | cut -d' ' -f1)"

# --- Case 1: matching hash -> identical output, no re-encrypt --------------
TARGET="$WORK/target.yaml"
{
  printf '#PLAINTEXT-SHA256: %s\n' "$SHA"
  printf 'SOPS-ENC:already-encrypted-bytes\n'
} > "$TARGET"
EXPECTED="$(cat "$TARGET")"

OUT="$(printf '%s' "$PLAINTEXT" | TARGET_PATH="$TARGET" render)"
[ "$OUT" = "$EXPECTED" ] || fail "case1: expected byte-identical target, got re-encrypt"
# Output must carry the existing encrypted body verbatim.
[[ "$OUT" == *"SOPS-ENC:already-encrypted-bytes"* ]] || fail "case1: output not the existing target body"
# Ensure it did NOT freshly encrypt the plaintext.
[[ "$OUT" != *"$(printf '%s' "$PLAINTEXT" | base64 -w0)"* ]] || fail "case1: re-encrypted despite matching hash"
echo "case1 PASS: matching hash -> identical, no re-encrypt"

# --- Case 2: mutated plaintext -> hash differs -> re-encrypt ---------------
MUTATED='apiVersion: v1
kind: SopsSecret
plaintext: changed-password'
OUT2="$(printf '%s' "$MUTATED" | TARGET_PATH="$TARGET" render)"
case "$OUT2" in
  SOPS-ENC:*) : ;;
  *) fail "case2: expected re-encrypted output" ;;
esac
[ "$OUT2" != "$EXPECTED" ] || fail "case2: output unchanged despite mutated plaintext"
# The re-encrypted body must contain the freshly-stamped new hash.
NEWSHA="$(printf '%s' "$MUTATED" | sha256sum | cut -d' ' -f1)"
DEC="$(printf '%s' "${OUT2#SOPS-ENC:}" | base64 -d)"
[[ "$DEC" == *"$NEWSHA"* ]] || fail "case2: re-encrypted body missing new hash"
echo "case2 PASS: mutated plaintext -> hash differs -> re-encrypt"

# --- Case 3: encrypted annotations -> read yields "" -> fail-closed --------
# Target with encrypted annotations: no readable #PLAINTEXT-SHA256 line.
ENC_TARGET="$WORK/enc-target.yaml"
printf 'SOPS-ENC:fully-encrypted-including-annotations\n' > "$ENC_TARGET"
PREV="$(yq -r '.metadata.annotations["secrets.json64.dev/plaintext-sha256"] // ""' "$ENC_TARGET")"
[ "$PREV" = "" ] || fail "case3: expected empty annotation read on encrypted target"
OUT3="$(printf '%s' "$PLAINTEXT" | TARGET_PATH="$ENC_TARGET" render)"
case "$OUT3" in
  SOPS-ENC:*) : ;;
  *) fail "case3: expected fail-closed re-encrypt" ;;
esac
[ "$OUT3" != "$(cat "$ENC_TARGET")" ] || fail "case3: did not re-encrypt"
echo "case3 PASS: encrypted annotations -> fail-closed re-encrypt"

echo "PASS"
