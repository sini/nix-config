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
    # Script to cycle through Kubernetes cluster states on axon nodes
    # State 0: All disabled (cleanup)
    # State 1: Only axon-01 enabled (bootstrap cluster)
    # State 2: axon-01 and axon-02 enabled (second node joins)
    # State 3: All three enabled (third node joins)
    # Then cycles back to State 0

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

    # Check if a specific file has kubernetes enabled
    is_enabled() {
      local file="$1"
      if grep -q '^[[:space:]]*"kubernetes"[[:space:]]*#[[:space:]]*TOGGLE_ENABLE/DISABLE' "$file"; then
        return 0  # enabled
      else
        return 1  # disabled
      fi
    }

    # Detect current state (0-3) based on which nodes have kubernetes enabled
    # State 0: none enabled (000)
    # State 1: only axon-01 enabled (100)
    # State 2: axon-01 and axon-02 enabled (110)
    # State 3: all three enabled (111)
    detect_state() {
      local enabled_count=0
      local pattern=""

      for file in "''${FILES[@]}"; do
        if is_enabled "$file"; then
          pattern="''${pattern}1"
          ((enabled_count++))
        else
          pattern="''${pattern}0"
        fi
      done

      case "$pattern" in
        "000") echo "0" ;;
        "100") echo "1" ;;
        "110") echo "2" ;;
        "111") echo "3" ;;
        *) echo "unknown:$pattern" ;;
      esac
    }

    # Enable kubernetes in a specific file (uncomment the line)
    enable_file() {
      local file="$1"
      local tmp_file="''${file}.tmp"

      while IFS= read -r line; do
        if [[ "$line" =~ TOGGLE_ENABLE/DISABLE ]]; then
          if [[ "$line" =~ ^([[:space:]]*)#[[:space:]]+(\".*)[[:space:]]+#[[:space:]]+TOGGLE_ENABLE/DISABLE ]]; then
            # Uncomment: remove the "# " before the quote
            local indent="''${BASH_REMATCH[1]}"
            local content="''${BASH_REMATCH[2]}"
            echo "''${indent}''${content} # TOGGLE_ENABLE/DISABLE"
          else
            # Already enabled or unexpected format
            echo "$line"
          fi
        else
          echo "$line"
        fi
      done < "$file" > "$tmp_file"

      mv "$tmp_file" "$file"
    }

    # Disable kubernetes in a specific file (comment the line)
    disable_file() {
      local file="$1"
      local tmp_file="''${file}.tmp"

      while IFS= read -r line; do
        if [[ "$line" =~ TOGGLE_ENABLE/DISABLE ]]; then
          if [[ "$line" =~ ^([[:space:]]+)(\".*)[[:space:]]+#[[:space:]]+TOGGLE_ENABLE/DISABLE ]]; then
            # Comment: add "# " before the quote
            local indent="''${BASH_REMATCH[1]}"
            local content="''${BASH_REMATCH[2]}"
            echo "''${indent}# ''${content} # TOGGLE_ENABLE/DISABLE"
          else
            # Already disabled or unexpected format
            echo "$line"
          fi
        else
          echo "$line"
        fi
      done < "$file" > "$tmp_file"

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

    # State 0 -> State 1: Enable axon-01, bootstrap cluster
    deploy_0_to_1() {
      echo ""
      echo "==> Deploying axon-01 (bootstrap cluster)..."
      echo "    Applying configuration and rebooting..."
      colmena apply --on axon-01 --reboot

      echo ""
      echo "==> Copying kubeconfig..."
      sleep 5  # Give k3s a moment to start
      scp sini@axon-01:/etc/rancher/k3s/k3s.yaml "''${HOME}/.config/kube/config" && sed -i 's/0.0.0.0/10.10.10.100/' "''${HOME}/.config/kube/config"

      echo ""
      echo "==> Cluster bootstrapped on axon-01"
    }

    # State 1 -> State 2: Enable axon-02, join cluster
    deploy_1_to_2() {
      echo ""
      echo "==> Deploying axon-02 (second node joins cluster)..."
      echo "    Applying configuration and rebooting..."
      colmena apply --on axon-02 --reboot

      echo ""
      echo "==> axon-02 joined the cluster"
    }

    # State 2 -> State 3: Enable axon-03, join cluster
    deploy_2_to_3() {
      echo ""
      echo "==> Deploying axon-03 (third node joins cluster)..."
      echo "    Applying configuration and rebooting..."
      colmena apply --on axon-03 --reboot

      echo ""
      echo "==> Cluster fully deployed (all 3 nodes)"
    }

    # State 3 -> State 0: Disable all, cleanup
    deploy_3_to_0() {
      echo ""
      echo "==> Disabling cluster on all nodes..."
      echo "    This will reboot all three nodes in parallel after applying config"
      colmena apply --on axon-01,axon-02,axon-03 --reboot -p1

      echo ""
      echo "==> Cleaning Kubernetes installation files..."
      colmena exec --on axon-01,axon-02,axon-03 -- rm -rf /persist/var/lib/rancher /persist/var/lib/kubelet /persist/etc/rancher /persist/var/lib/cni /persist/var/lib/containers /persist/var/lib/containerd

      echo ""
      echo "==> Cluster fully disabled and cleaned up"
    }

    main() {
      # Change to repository root
      cd "$REPO_ROOT"

      # Detect current state
      CURRENT_STATE=$(detect_state)
      if [[ "$CURRENT_STATE" == unknown:* ]]; then
        echo "Error: Unexpected cluster state: ''${CURRENT_STATE#unknown:}" >&2
        echo "Expected one of: 000 (all disabled), 100 (axon-01 only), 110 (axon-01,02), 111 (all enabled)" >&2
        exit 1
      fi

      # Determine next state and action
      case "$CURRENT_STATE" in
        0)
          NEXT_STATE=1
          STATE_DESC="State 0 (all disabled) -> State 1 (axon-01 only)"
          COMMIT_MSG="enable axon-01 (bootstrap cluster)"
          ;;
        1)
          NEXT_STATE=2
          STATE_DESC="State 1 (axon-01 only) -> State 2 (axon-01 + axon-02)"
          COMMIT_MSG="enable axon-02 (second node)"
          ;;
        2)
          NEXT_STATE=3
          STATE_DESC="State 2 (axon-01,02) -> State 3 (all nodes)"
          COMMIT_MSG="enable axon-03 (third node)"
          ;;
        3)
          NEXT_STATE=0
          STATE_DESC="State 3 (all enabled) -> State 0 (all disabled)"
          COMMIT_MSG="disable axon cluster"
          ;;
      esac

      echo "=========================================="
      echo "Axon Cluster State Cycle Script"
      echo "=========================================="
      echo "Current state: $CURRENT_STATE"
      echo "Next state: $NEXT_STATE"
      echo "Transition: $STATE_DESC"
      echo "=========================================="
      echo ""

      # Verify all files exist
      for file in "''${FILES[@]}"; do
        if [[ ! -f "$file" ]]; then
          echo "Error: File not found: $file" >&2
          exit 1
        fi
      done

      # Apply configuration changes based on state transition
      echo "==> Updating configuration files..."
      case "$NEXT_STATE" in
        0)
          # Disable all nodes
          echo "    Disabling: axon-01, axon-02, axon-03"
          disable_file "''${FILES[0]}"
          disable_file "''${FILES[1]}"
          disable_file "''${FILES[2]}"
          ;;
        1)
          # Enable only axon-01
          echo "    Enabling: axon-01"
          enable_file "''${FILES[0]}"
          ;;
        2)
          # Enable axon-01 and axon-02
          echo "    Enabling: axon-02"
          enable_file "''${FILES[1]}"
          ;;
        3)
          # Enable all three
          echo "    Enabling: axon-03"
          enable_file "''${FILES[2]}"
          ;;
      esac

      # Update manifests
      update_manifests

      # Commit and push
      commit_and_push "$COMMIT_MSG"

      # Deploy based on state transition
      case "''${CURRENT_STATE}_to_''${NEXT_STATE}" in
        0_to_1) deploy_0_to_1 ;;
        1_to_2) deploy_1_to_2 ;;
        2_to_3) deploy_2_to_3 ;;
        3_to_0) deploy_3_to_0 ;;
      esac

      echo ""
      echo "=========================================="
      echo "✓ Successfully transitioned to state $NEXT_STATE"
      echo "=========================================="
    }

    main "$@"
  '';
}
