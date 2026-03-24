{
  writeShellApplication,
  nix-output-monitor,
}:
writeShellApplication {
  name = "nix-flake-build";
  meta.description = "Build a host configuration";

  excludeShellChecks = [ "SC2068" ];

  runtimeInputs = [ nix-output-monitor ];
  text = ''
    APPLY=false
    OPTIONS=()
    HOST_NAMES=()

    for arg in "$@"; do
      if [[ "$arg" == "--apply" ]]; then
        APPLY=true
      elif [[ "$arg" == -* ]]; then
        # Split arguments containing = into separate option and value
        if [[ "$arg" == *=* ]]; then
          IFS='=' read -r opt val <<< "$arg"
          OPTIONS+=("$opt" "$val")
        else
          OPTIONS+=("$arg")
        fi
      else
        HOST_NAMES+=("$arg")
      fi
    done

    # Default to current hostname if no hosts specified
    if [[ "''${#HOST_NAMES[@]}" -eq 0 ]]; then
      HOST_NAMES=("$(hostname)")
    fi

    if [[ "$APPLY" == true && "''${#HOST_NAMES[@]}" -gt 1 ]]; then
      echo "error: --apply only supports a single host" >&2
      exit 1
    fi

    HOSTS=()
    HOST_SYSTEMS=()
    for h in "''${HOST_NAMES[@]}"; do
      HOST_SYSTEM=$(nix eval --raw ".#hosts.$h.system" 2>/dev/null || echo "x86_64-linux")
      HOST_SYSTEMS+=("$HOST_SYSTEM")
      if [[ "$HOST_SYSTEM" == *darwin* ]]; then
        HOSTS+=(".#darwinConfigurations.$h.config.system.build.toplevel")
      else
        HOSTS+=(".#nixosConfigurations.$h.config.system.build.toplevel")
      fi
    done

    nom build --keep-going --no-link --print-out-paths --show-trace ''${OPTIONS[@]} "''${HOSTS[@]}"

    if [[ "$APPLY" == true ]]; then
      h="''${HOST_NAMES[0]}"
      HOST_SYSTEM="''${HOST_SYSTEMS[0]}"

      if [[ "$HOST_SYSTEM" == *darwin* ]]; then
        echo "Applying darwin configuration for $h..."
        sudo -E darwin-rebuild switch --flake ".#$h"
      else
        echo "Applying NixOS configuration for $h..."
        sudo nixos-rebuild switch --flake ".#$h"
      fi
    fi
  '';
}
