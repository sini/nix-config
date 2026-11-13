# Runtime post-process command for SopsSecret resources: resolve vals refs, stamp
# two hashes, sops-encrypt. Shared by the objectTransforms postProcess rule and the
# idempotency check so they can't drift.
#
#   plaintext-sha256  the resolved manifest (values included): re-encrypt only when
#                     a value or field really changed.
#   source-sha256     the manifest as rendered, which holds `ref+sops://` references
#                     and never a value. A run with no key computes it, so
#                     `nixidy-sync --check-secrets` can tell a new or changed secret
#                     from an unchanged one without decrypting (_check-secrets.sh).
#
# Annotations sit outside sops' encrypted_regex (.sops.yaml: data|stringData), so
# both stay readable in the encrypted file.
''
  export SOPS_AGE_KEY_CMD="''${SOPS_AGE_KEY_CMD:-age-plugin-yubikey -i}"
  rendered=$(cat)
  src=$(printf '%s' "$rendered" | sha256sum | cut -d' ' -f1)
  resolved=$(printf '%s' "$rendered" | vals eval)
  sha=$(printf '%s' "$resolved" | sha256sum | cut -d' ' -f1)
  if [ -f "$TARGET_PATH" ]; then
    prev=$(yq -r '.metadata.annotations["secrets.json64.dev/plaintext-sha256"] // ""' "$TARGET_PATH")
    prevsrc=$(yq -r '.metadata.annotations["secrets.json64.dev/source-sha256"] // ""' "$TARGET_PATH")
    if [ "$prev" = "$sha" ] && [ "$prevsrc" = "$src" ]; then cat "$TARGET_PATH"; exit 0; fi
  fi
  printf '%s' "$resolved" \
    | yq '.metadata.annotations."secrets.json64.dev/plaintext-sha256" = "'"$sha"'" | .metadata.annotations."secrets.json64.dev/source-sha256" = "'"$src"'"' \
    | sops --config "$PWD/.sops.yaml" --filename-override "$TARGET_PATH" \
           --input-type yaml --output-type yaml -e /dev/stdin
''
