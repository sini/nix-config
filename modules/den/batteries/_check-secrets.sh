# check-secrets <environment-dir> <dest-dir>
#
# For every SopsSecret the environment renders, compare the hash of its rendered
# form (references only, no values) with the source-sha256 annotation stamped on
# the committed encrypted file in <dest-dir>
# (aspects/kubernetes/_secret-post-process-command.nix). Exit 1 and list each one
# that is new (no encrypted file) or changed (hash differs): a run with
# --skip-secrets would silently drop or keep it stale, so it needs a full
# nixidy-sync with the sops key. Needs no key.
env_dir=$1
dest_dir=$2
new=()
changed=()
while IFS= read -r -d "" f; do
  rel=${f#"$env_dir"/}
  [ "$(yq -r '.kind' "$f")" = SopsSecret ] || continue
  target="$dest_dir/$rel"
  if [ ! -f "$target" ]; then
    new+=("$rel")
    continue
  fi
  src=$(printf '%s' "$(cat "$f")" | sha256sum | cut -d' ' -f1)
  prevsrc=$(yq -r '.metadata.annotations["secrets.json64.dev/source-sha256"] // ""' "$target")
  [ "$prevsrc" = "$src" ] || changed+=("$rel")
done < <(find -L "$env_dir" -name '*.yaml' -type f -print0 | sort -z)

if [ ${#new[@]} -eq 0 ] && [ ${#changed[@]} -eq 0 ]; then
  echo "check-secrets: every SopsSecret matches its committed encrypted file"
  exit 0
fi
for r in "${new[@]}"; do echo "check-secrets: NEW     $r" >&2; done
for r in "${changed[@]}"; do echo "check-secrets: CHANGED $r" >&2; done
echo "check-secrets: ${#new[@]} new, ${#changed[@]} changed; run nixidy-sync with the sops key (no --skip-secrets)" >&2
exit 1
