{
  writeShellApplication,
  git,
  gnugrep,
  coreutils,
}:
writeShellApplication {
  name = "toggle-axon-kubernetes";
  meta.description = "Toggle enable/disable Kubernetes on axon cluster nodes";
  runtimeInputs = [
    git
    gnugrep
    coreutils
  ];
  text = ''
    # Script to toggle enable/disable Kubernetes on axon cluster nodes
    # This script will:
    # - Toggle kubernetes roles in axon host configurations
    # - Update Kubernetes manifests
    # - Commit and push changes
    # - Deploy changes and reboot nodes as needed
    # - Clean up Kubernetes install files if disabling

    # Find repository root
    REPO_ROOT="$(git rev-parse --show-toplevel)"
    if [[ ! -d "$REPO_ROOT" ]]; then
      echo "Error: Not in a git repository" >&2
      exit 1
    fi

    FILES=(
      "$REPO_ROOT/modules/hosts/axon-01/host.nix"
      "$REPO_ROOT/modules/hosts/axon-02/host.nix"
      "$REPO_ROOT/modules/hosts/axon-03/host.nix"
    )

    # Detect current state by checking first file
    detect_state() {
      local file="''${FILES[0]}"
      if grep -q '^[[:space:]]*"kubernetes"[[:space:]]*#[[:space:]]*TOGGLE_ENABLE/DISABLE' "$file"; then
        echo "enabled"
      elif grep -q '^[[:space:]]*#[[:space:]]*"kubernetes"[[:space:]]*#[[:space:]]*TOGGLE_ENABLE/DISABLE' "$file"; then
        echo "disabled"
      else
        echo "unknown"
      fi
    }

    toggle_line() {
      local file="$1"

      # Create a temporary file
      local tmp_file="''${file}.tmp"

      # Process each line
      while IFS= read -r line; do
        if [[ "$line" =~ TOGGLE_ENABLE/DISABLE ]]; then
          # Check if the line is currently commented
          if [[ "$line" =~ ^([[:space:]]*)#[[:space:]]+(\".*)[[:space:]]+#[[:space:]]+TOGGLE_ENABLE/DISABLE ]]; then
            # Uncomment: remove the "# " before the quote
            local indent="''${BASH_REMATCH[1]}"
            local content="''${BASH_REMATCH[2]}"
            echo "''${indent}''${content} # TOGGLE_ENABLE/DISABLE"
          elif [[ "$line" =~ ^([[:space:]]+)(\".*)[[:space:]]+#[[:space:]]+TOGGLE_ENABLE/DISABLE ]]; then
            # Comment: add "# " before the quote
            local indent="''${BASH_REMATCH[1]}"
            local content="''${BASH_REMATCH[2]}"
            echo "''${indent}# ''${content} # TOGGLE_ENABLE/DISABLE"
          else
            # Line has TOGGLE_ENABLE/DISABLE but doesn't match expected format
            echo "$line"
          fi
        else
          # Not a toggle line, keep as-is
          echo "$line"
        fi
      done < "$file" > "$tmp_file"

      # Replace original file with processed version
      mv "$tmp_file" "$file"
    }

    update_manifests() {
      echo ""
      echo "==> Updating Kubernetes manifests..."
      cd "$REPO_ROOT"
      nix run .#k8s-update-manifests -- --skip-secrets
    }

    commit_and_push() {
      local action="$1"
      echo ""
      echo "==> Committing and pushing changes..."
      cd "$REPO_ROOT"
      git add modules/hosts/axon-*/host.nix kubernetes/generated/manifests/
      git commit -m "chore: ''${action} axon cluster"
      git push
    }

    deploy_disable() {
      echo ""
      echo "==> Deploying configuration changes (disabling cluster)..."
      echo "    This will reboot all three nodes in parallel after applying config"
      colmena apply --on axon-01,axon-02,axon-03 --reboot -p1

      echo ""
      echo "==> Cleaning Kubernetes installation files..."
      colmena exec --on axon-01,axon-02,axon-03 -- rm -rf /persist/var/lib/rancher /persist/var/lib/kubelet /persist/etc/rancher /persist/var/lib/cni /persist/var/lib/containers /persist/var/lib/containerd
    }

    deploy_enable() {
      echo ""
      echo "==> Deploying configuration changes (enabling cluster)..."
      echo "    Applying to axon-01 first and waiting for reboot..."
      colmena apply --on axon-01 --reboot
      scp sini@axon-01:/etc/rancher/k3s/k3s.yaml "''${HOME}/.config/kube/config" && sed -i 's/0.0.0.0/axon-01.ts.json64.dev/' "''${HOME}/.config/kube/config"
    }

    main() {
      # Change to repository root
      cd "$REPO_ROOT"

      # Detect current state
      CURRENT_STATE=$(detect_state)
      if [[ "$CURRENT_STATE" == "unknown" ]]; then
        echo "Error: Could not detect current kubernetes state" >&2
        exit 1
      fi

      # Determine action
      if [[ "$CURRENT_STATE" == "enabled" ]]; then
        ACTION="disable"
        NEW_STATE="disabled"
      else
        ACTION="enable"
        NEW_STATE="enabled"
      fi

      echo "=========================================="
      echo "Axon Cluster Toggle Script"
      echo "=========================================="
      echo "Current state: $CURRENT_STATE"
      echo "Action: $ACTION kubernetes"
      echo "New state: $NEW_STATE"
      echo "=========================================="
      echo ""

      # Toggle configuration files
      echo "==> Toggling configuration files..."
      for file in "''${FILES[@]}"; do
        if [[ ! -f "$file" ]]; then
          echo "Error: File not found: $file" >&2
          exit 1
        fi
        echo "    Processing: $file"
        toggle_line "$file"
      done

      # Update manifests
      update_manifests

      # Commit and push
      commit_and_push "$ACTION"

      # Deploy based on action
      if [[ "$ACTION" == "disable" ]]; then
        deploy_disable
      else
        deploy_enable
      fi

      echo ""
      echo "=========================================="
      echo "✓ Successfully ''${ACTION}d axon cluster"
      echo "=========================================="
    }

    main "$@"
  '';
}
