{
  writeShellApplication,
  nix,
  jq,
  coreutils,
}:
writeShellApplication {
  name = "impermanence-copy";
  runtimeInputs = [
    nix
    jq
    coreutils
  ];
  text = ''
    set -euo pipefail

    # Color output
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m' # No Color

    info() { echo -e "''${BLUE}[INFO]''${NC} $*"; }
    success() { echo -e "''${GREEN}[SUCCESS]''${NC} $*"; }
    warn() { echo -e "''${YELLOW}[WARN]''${NC} $*"; }
    error() { echo -e "''${RED}[ERROR]''${NC} $*"; }
    cmd() { echo -e "''${CYAN}[CMD]''${NC} $*"; }

    # Parse arguments
    DRY_RUN=true  # Default to dry-run during development
    HOSTNAME=""
    FLAKE_REF="."  # Default to current directory

    while [[ "$#" -gt 0 ]]; do
      case "$1" in
        --dry-run)
          DRY_RUN=true
          shift
          ;;
        --no-dry-run)
          DRY_RUN=false
          shift
          ;;
        --flake)
          FLAKE_REF="$2"
          shift 2
          ;;
        *)
          if [[ -z "$HOSTNAME" ]]; then
            HOSTNAME="$1"
          else
            error "Unknown argument: $1"
            exit 1
          fi
          shift
          ;;
      esac
    done

    if [[ -z "$HOSTNAME" ]]; then
      error "usage: impermanence-copy [--dry-run] [--flake FLAKE_REF] <HOSTNAME>"
      exit 1
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
      warn "DRY RUN MODE - No files will be copied"
      echo ""
    fi

    info "Using flake: $FLAKE_REF"
    info "Checking if impermanence is enabled for $HOSTNAME..."
    IMPERMANENCE_ENABLED=$(nix eval --json "$FLAKE_REF#nixosConfigurations.$HOSTNAME.config.impermanence.enable" 2>/dev/null || echo "false")

    if [[ "$IMPERMANENCE_ENABLED" != "true" ]]; then
      error "Impermanence is not enabled for $HOSTNAME"
      error "Evaluated: $FLAKE_REF#nixosConfigurations.$HOSTNAME.config.impermanence.enable = $IMPERMANENCE_ENABLED"
      exit 1
    fi

    info "Extracting persistence configuration for $HOSTNAME..."

    # Get all persistence volume names
    PERSISTENCE_VOLUMES=$(nix eval --json "$FLAKE_REF#nixosConfigurations.$HOSTNAME.config.environment.persistence" --apply 'builtins.attrNames' 2>/dev/null || echo "[]")

    if [[ "$PERSISTENCE_VOLUMES" == "[]" ]]; then
      warn "No persistence volumes configured for $HOSTNAME"
      exit 0
    fi

    echo ""
    echo "=== Persistence Configuration for $HOSTNAME ==="
    echo ""

    # Function to process and show copy operations for items
    process_item() {
      local item_json="$1"
      local storage_path="$2"
      local item_type="$3"  # "file" or "directory"

      # Extract metadata from JSON
      local src
      src=$(echo "$item_json" | jq -r ".$item_type // empty")
      [[ -z "$src" ]] && return

      local mode
      mode=$(echo "$item_json" | jq -r '.mode // "0755"')
      local user
      user=$(echo "$item_json" | jq -r '.user // "root"')
      local group
      group=$(echo "$item_json" | jq -r '.group // "root"')

      local dest="$storage_path$src"
      local dest_dir
      dest_dir=$(dirname "$dest")

      # Check existence
      local src_exists=false
      local dest_exists=false
      [[ -e "$src" ]] && src_exists=true
      [[ -e "$dest" ]] && dest_exists=true

      # Status indicators
      local src_status="❌"
      local dest_status="❌"
      [[ "$src_exists" == "true" ]] && src_status="✓"
      [[ "$dest_exists" == "true" ]] && dest_status="✓"

      # Show status
      printf "  [%s] %-50s -> [%s] %s\n" "$src_status" "$src" "$dest_status" "$dest"

      # Copy or show copy commands based on mode
      if [[ "$src_exists" == "true" && "$dest_exists" == "false" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
          cmd "  mkdir -p $dest_dir"
          cmd "  cp -a $src $dest"
          cmd "  chown $user:$group $dest"
          cmd "  chmod $mode $dest"
          echo ""
        else
          info "  Copying: $src -> $dest"
          mkdir -p "$dest_dir" || { error "Failed to create directory: $dest_dir"; return 1; }
          cp -a "$src" "$dest" || { error "Failed to copy: $src"; return 1; }
          chown "$user:$group" "$dest" || { error "Failed to set ownership: $dest"; return 1; }
          chmod "$mode" "$dest" || { error "Failed to set permissions: $dest"; return 1; }
          success "  Copied: $src"
        fi
      elif [[ "$src_exists" == "false" ]]; then
        warn "  Source does not exist: $src"
      elif [[ "$dest_exists" == "true" ]]; then
        info "  Already exists in persist: $dest (skipping)"
      fi
    }

    # Function to process user items (handles relative paths correctly)
    process_user_item() {
      local src_full="$1"       # Full source path for existence check
      local relative_path="$2"  # Relative path for destination
      local storage_path="$3"
      local mode="$4"
      local user="$5"
      local group="$6"

      local dest="$storage_path/$relative_path"
      local dest_dir
      dest_dir=$(dirname "$dest")

      # Check existence
      local src_exists=false
      local dest_exists=false
      [[ -e "$src_full" ]] && src_exists=true
      [[ -e "$dest" ]] && dest_exists=true

      # Status indicators
      local src_status="❌"
      local dest_status="❌"
      [[ "$src_exists" == "true" ]] && src_status="✓"
      [[ "$dest_exists" == "true" ]] && dest_status="✓"

      # Show status
      printf "  [%s] %-50s -> [%s] %s\n" "$src_status" "$src_full" "$dest_status" "$dest"

      # Copy or show copy commands based on mode
      if [[ "$src_exists" == "true" && "$dest_exists" == "false" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
          cmd "  mkdir -p $dest_dir"
          cmd "  cp -a $src_full $dest"
          cmd "  chown $user:$group $dest"
          cmd "  chmod $mode $dest"
          echo ""
        else
          info "  Copying: $src_full -> $dest"
          mkdir -p "$dest_dir" || { error "Failed to create directory: $dest_dir"; return 1; }
          cp -a "$src_full" "$dest" || { error "Failed to copy: $src_full"; return 1; }
          chown "$user:$group" "$dest" || { error "Failed to set ownership: $dest"; return 1; }
          chmod "$mode" "$dest" || { error "Failed to set permissions: $dest"; return 1; }
          success "  Copied: $src_full"
        fi
      elif [[ "$src_exists" == "false" ]]; then
        warn "  Source does not exist: $src_full"
      elif [[ "$dest_exists" == "true" ]]; then
        info "  Already exists in persist: $dest (skipping)"
      fi
    }

    # Process system-level persistence volumes
    echo "### SYSTEM-LEVEL PERSISTENCE ###"
    echo ""
    echo "$PERSISTENCE_VOLUMES" | jq -r '.[]' | while IFS= read -r volume_name; do
      info "Processing system volume: $volume_name"

      # Get configuration for this volume
      VOLUME_CONFIG=$(nix eval --json "$FLAKE_REF#nixosConfigurations.$HOSTNAME.config.environment.persistence.\"$volume_name\"" 2>/dev/null || echo "{}")

      # Extract the actual storage path (where files will be persisted)
      STORAGE_PATH=$(echo "$VOLUME_CONFIG" | jq -r '.persistentStoragePath // empty')

      if [[ -z "$STORAGE_PATH" ]]; then
        warn "No persistentStoragePath found for volume $volume_name, skipping"
        continue
      fi

      echo ""
      echo "=== Volume: $volume_name -> $STORAGE_PATH ==="
      echo ""

      # Process files for this volume
      echo "--- Files ---"
      VOLUME_FILES_COUNT=$(echo "$VOLUME_CONFIG" | jq '.files | length')
      if [[ "$VOLUME_FILES_COUNT" -gt 0 ]]; then
        for i in $(seq 0 $((VOLUME_FILES_COUNT - 1))); do
          FILE_JSON=$(echo "$VOLUME_CONFIG" | jq -c ".files[$i]")
          process_item "$FILE_JSON" "$STORAGE_PATH" "file"
        done
      else
        echo "  (none configured)"
      fi
      echo ""

      # Process directories for this volume
      echo "--- Directories ---"
      VOLUME_DIRS_COUNT=$(echo "$VOLUME_CONFIG" | jq '.directories | length')
      if [[ "$VOLUME_DIRS_COUNT" -gt 0 ]]; then
        for i in $(seq 0 $((VOLUME_DIRS_COUNT - 1))); do
          DIR_JSON=$(echo "$VOLUME_CONFIG" | jq -c ".directories[$i]")
          process_item "$DIR_JSON" "$STORAGE_PATH" "directory"
        done
      else
        echo "  (none configured)"
      fi
      echo ""
    done

    # Process user-level persistence (home-manager)
    echo ""
    echo "### USER-LEVEL PERSISTENCE (HOME-MANAGER) ###"
    echo ""

    # Get list of home-manager users
    HM_USERS=$(nix eval --json "$FLAKE_REF#nixosConfigurations.$HOSTNAME.config.home-manager.users" --apply 'builtins.attrNames' 2>/dev/null || echo "[]")

    if [[ "$HM_USERS" == "[]" ]]; then
      info "No home-manager users configured"
    else
      echo "$HM_USERS" | jq -r '.[]' | while IFS= read -r username; do
        info "Processing user: $username"

        # Get user's home directory
        USER_HOME=$(nix eval --raw "$FLAKE_REF#nixosConfigurations.$HOSTNAME.config.home-manager.users.$username.home.homeDirectory" 2>/dev/null || echo "")
        if [[ -z "$USER_HOME" ]]; then
          warn "Could not determine home directory for user $username, skipping"
          continue
        fi

        # Get user's persistence configuration
        USER_PERSISTENCE=$(nix eval --json "$FLAKE_REF#nixosConfigurations.$HOSTNAME.config.home-manager.users.$username.home.persistence" 2>/dev/null || echo "{}")

        # Get list of user persistence volumes
        USER_VOLUMES=$(echo "$USER_PERSISTENCE" | jq -r 'keys[]' 2>/dev/null || echo "")

        if [[ -z "$USER_VOLUMES" ]]; then
          info "No persistence volumes configured for user $username"
          continue
        fi

        echo "$USER_VOLUMES" | while IFS= read -r user_volume_name; do
          [[ -z "$user_volume_name" ]] && continue

          info "  Processing user volume: $user_volume_name"

          # Get configuration for this user volume
          USER_VOLUME_CONFIG=$(echo "$USER_PERSISTENCE" | jq -c ".\"$user_volume_name\"")

          # Check if volume is enabled
          USER_VOLUME_ENABLED=$(echo "$USER_VOLUME_CONFIG" | jq -r '.enable // false')
          if [[ "$USER_VOLUME_ENABLED" != "true" ]]; then
            warn "  Volume $user_volume_name is not enabled for user $username, skipping"
            continue
          fi

          # Extract the actual storage path
          USER_STORAGE_PATH=$(echo "$USER_VOLUME_CONFIG" | jq -r '.persistentStoragePath // empty')

          if [[ -z "$USER_STORAGE_PATH" ]]; then
            warn "  No persistentStoragePath found for user volume $user_volume_name, skipping"
            continue
          fi

          echo ""
          echo "  === User: $username | Volume: $user_volume_name -> $USER_STORAGE_PATH ==="
          echo ""

          # Process user files for this volume
          echo "  --- Files ---"
          USER_FILES_COUNT=$(echo "$USER_VOLUME_CONFIG" | jq '.files | length')
          if [[ "$USER_FILES_COUNT" -gt 0 ]]; then
            for i in $(seq 0 $((USER_FILES_COUNT - 1))); do
              USER_FILE_JSON=$(echo "$USER_VOLUME_CONFIG" | jq -c ".files[$i]")
              # Extract file path (could be string or object with .file)
              if echo "$USER_FILE_JSON" | jq -e 'type == "string"' >/dev/null 2>&1; then
                RELATIVE_PATH=$(echo "$USER_FILE_JSON" | jq -r '.')
                MODE="0644"
                USER_OWNER="$username"
                GROUP_OWNER="users"
              else
                RELATIVE_PATH=$(echo "$USER_FILE_JSON" | jq -r '.file // .filePath // empty')
                MODE=$(echo "$USER_FILE_JSON" | jq -r '.mode // "0644"')
                USER_OWNER=$(echo "$USER_FILE_JSON" | jq -r --arg user "$username" '.user // $user')
                GROUP_OWNER=$(echo "$USER_FILE_JSON" | jq -r '.group // "users"')
              fi

              [[ -z "$RELATIVE_PATH" ]] && continue

              # Construct full source path and determine relative path for destination
              if [[ "$RELATIVE_PATH" = /* ]]; then
                # Absolute path - use as-is for source
                SRC_FULL="$RELATIVE_PATH"
                # Strip home directory prefix if present to get relative path for destination
                if [[ "$RELATIVE_PATH" = "$USER_HOME"/* ]]; then
                  DEST_RELATIVE="''${RELATIVE_PATH#"$USER_HOME"/}"
                else
                  # Absolute path outside home - keep as-is
                  DEST_RELATIVE="$RELATIVE_PATH"
                fi
              else
                # Relative path - prepend home for source
                SRC_FULL="$USER_HOME/$RELATIVE_PATH"
                DEST_RELATIVE="$RELATIVE_PATH"
              fi

              process_user_item "$SRC_FULL" "$DEST_RELATIVE" "$USER_STORAGE_PATH" "$MODE" "$USER_OWNER" "$GROUP_OWNER"
            done
          else
            echo "    (none configured)"
          fi
          echo ""

          # Process user directories for this volume
          echo "  --- Directories ---"
          USER_DIRS_COUNT=$(echo "$USER_VOLUME_CONFIG" | jq '.directories | length')
          if [[ "$USER_DIRS_COUNT" -gt 0 ]]; then
            for i in $(seq 0 $((USER_DIRS_COUNT - 1))); do
              USER_DIR_JSON=$(echo "$USER_VOLUME_CONFIG" | jq -c ".directories[$i]")
              # Extract directory path (could be string or object with .directory)
              if echo "$USER_DIR_JSON" | jq -e 'type == "string"' >/dev/null 2>&1; then
                RELATIVE_PATH=$(echo "$USER_DIR_JSON" | jq -r '.')
                MODE="0755"
                USER_OWNER="$username"
                GROUP_OWNER="users"
              else
                RELATIVE_PATH=$(echo "$USER_DIR_JSON" | jq -r '.directory // .dirPath // empty')
                MODE=$(echo "$USER_DIR_JSON" | jq -r '.mode // "0755"')
                USER_OWNER=$(echo "$USER_DIR_JSON" | jq -r --arg user "$username" '.user // $user')
                GROUP_OWNER=$(echo "$USER_DIR_JSON" | jq -r '.group // "users"')
              fi

              [[ -z "$RELATIVE_PATH" ]] && continue

              # Construct full source path and determine relative path for destination
              if [[ "$RELATIVE_PATH" = /* ]]; then
                # Absolute path - use as-is for source
                SRC_FULL="$RELATIVE_PATH"
                # Strip home directory prefix if present to get relative path for destination
                if [[ "$RELATIVE_PATH" = "$USER_HOME"/* ]]; then
                  DEST_RELATIVE="''${RELATIVE_PATH#"$USER_HOME"/}"
                else
                  # Absolute path outside home - keep as-is
                  DEST_RELATIVE="$RELATIVE_PATH"
                fi
              else
                # Relative path - prepend home for source
                SRC_FULL="$USER_HOME/$RELATIVE_PATH"
                DEST_RELATIVE="$RELATIVE_PATH"
              fi

              process_user_item "$SRC_FULL" "$DEST_RELATIVE" "$USER_STORAGE_PATH" "$MODE" "$USER_OWNER" "$GROUP_OWNER"
            done
          else
            echo "    (none configured)"
          fi
          echo ""
        done
      done
    fi

    echo ""
    if [[ "$DRY_RUN" == "true" ]]; then
      success "Dry-run complete!"
      info "Legend: [✓] = exists, [❌] = does not exist"
      info "Run with --no-dry-run to execute copy operations"
    else
      success "Copy operations complete!"
      info "Legend: [✓] = exists, [❌] = does not exist"
      info "Files already in persist were skipped to avoid overwriting existing data"
    fi
  '';
}
