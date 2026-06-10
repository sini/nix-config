# Runtime post-process command for SopsSecret resources: resolve vals refs,
# stamp a plaintext-sha256 annotation for idempotency, sops-encrypt. Shared by
# the objectTransforms postProcess rule and the idempotency check so they
# can't drift.
''
  resolved=$(vals eval)
  sha=$(printf '%s' "$resolved" | sha256sum | cut -d' ' -f1)
  if [ -f "$TARGET_PATH" ]; then
    prev=$(yq -r '.metadata.annotations["secrets.json64.dev/plaintext-sha256"] // ""' "$TARGET_PATH")
    if [ "$prev" = "$sha" ]; then cat "$TARGET_PATH"; exit 0; fi
  fi
  printf '%s' "$resolved" \
    | yq '.metadata.annotations."secrets.json64.dev/plaintext-sha256" = "'"$sha"'"' \
    | SOPS_AGE_KEY_CMD="age-plugin-yubikey -i" \
      sops --config "$PWD/.sops.yaml" --filename-override "$TARGET_PATH" \
           --input-type yaml --output-type yaml -e /dev/stdin
''
