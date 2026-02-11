{
  writeShellApplication,
  gh,
  jq,
  nix,
}:
writeShellApplication {
  name = "nix-flake-update";
  meta.description = "Update flake inputs with GitHub access token";
  runtimeInputs = [
    gh
    jq
    nix
  ];
  text = ''
    excludes=()

    # Parse arguments
    while [[ $# -gt 0 ]]; do
      case $1 in
        --exclude|-e)
          excludes+=("$2")
          shift 2
          ;;
        --help|-h)
          echo "Usage: nix-flake-update [OPTIONS]"
          echo ""
          echo "Options:"
          echo "  -e, --exclude INPUT   Exclude INPUT from update (can be specified multiple times)"
          echo "  -h, --help            Show this help message"
          exit 0
          ;;
        *)
          echo "Unknown option: $1"
          exit 1
          ;;
      esac
    done

    # Check GitHub CLI auth status
    if ! gh auth status &>/dev/null; then
      echo "GitHub CLI not authenticated. Logging in..."
      gh auth login
    fi

    ACCESS_TOKEN="github.com=$(gh auth token)"

    if [[ ''${#excludes[@]} -eq 0 ]]; then
      # No excludes, update everything
      nix flake update --option access-tokens "$ACCESS_TOKEN"
    else
      # Build jq filter to exclude specified inputs
      jq_filter=".locks.nodes.root.inputs | keys[]"
      for exclude in "''${excludes[@]}"; do
        jq_filter="$jq_filter | select(. != \"$exclude\")"
      done

      # Get inputs to update
      inputs=$(nix flake metadata --json | jq -r "$jq_filter")

      if [[ -z "$inputs" ]]; then
        echo "No inputs to update after exclusions"
        exit 0
      fi

      # Build update-input arguments
      update_args=()
      while IFS= read -r input; do
        update_args+=("$input")
      done <<< "$inputs"

      echo "Updating inputs: $(echo "$inputs" | tr '\n' ' ')"
      echo "Excluding: ''${excludes[*]}"

      nix flake update --option access-tokens "$ACCESS_TOKEN" "''${update_args[@]}"
    fi
  '';
}
