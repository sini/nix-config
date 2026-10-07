{
  writeShellApplication,
  awscli2,
  kubectl,
  jq,
}:
writeShellApplication {
  name = "publish-sites";
  meta.description = "Sync sites/<domain>/ to its Garage website bucket";
  runtimeInputs = [
    awscli2
    kubectl
    jq
  ];
  text = ''
    # Usage: publish-sites [--dry-run] [domain ...]   (default: every sites/<domain>/)
    # Credentials come from the operator-minted sites-publisher key in the cluster
    # (garage/sites-publisher-credentials) and live only in this process's env.
    root=$(git rev-parse --show-toplevel)/sites
    endpoint=''${PUBLISH_SITES_ENDPOINT:-https://s3.json64.dev}
    dry=()
    if [[ ''${1:-} == --dry-run ]]; then
      dry=(--dryrun)
      shift
    fi

    if [[ $# -gt 0 ]]; then
      domains=("$@")
    else
      mapfile -t domains < <(find "$root" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
    fi

    creds=$(kubectl -n garage get secret sites-publisher-credentials -o json)
    AWS_ACCESS_KEY_ID=$(jq -r '.data["access-key-id"] | @base64d' <<<"$creds")
    AWS_SECRET_ACCESS_KEY=$(jq -r '.data["secret-access-key"] | @base64d' <<<"$creds")
    export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
    export AWS_DEFAULT_REGION=garage
    unset creds

    for domain in "''${domains[@]}"; do
      src="$root/$domain"
      if [[ ! -d $src ]]; then
        echo "publish-sites: no $src" >&2
        exit 1
      fi
      echo "==> $domain"
      aws s3 sync "$src/" "s3://$domain/" --delete --endpoint-url "$endpoint" "''${dry[@]}"
    done
  '';
}
