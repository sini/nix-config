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

    # Darwin hosts live under darwinConfigurations; everything else is NixOS.
    # attrNames is lazy, so this does not evaluate any host configuration.
    DARWIN_HOSTS=" $(nix eval --raw ".#darwinConfigurations" --apply \
      'cfgs: builtins.concatStringsSep " " (builtins.attrNames cfgs)' 2>/dev/null) "

    HOSTS=()
    HOST_IS_DARWIN=()
    for h in "''${HOST_NAMES[@]}"; do
      if [[ "$DARWIN_HOSTS" == *" $h "* ]]; then
        HOST_IS_DARWIN+=("true")
        HOSTS+=(".#darwinConfigurations.$h.config.system.build.toplevel")
      else
        HOST_IS_DARWIN+=("false")
        HOSTS+=(".#nixosConfigurations.$h.config.system.build.toplevel")
      fi
    done

    nom build --keep-going --no-link --print-out-paths --show-trace ''${OPTIONS[@]} "''${HOSTS[@]}"

    if [[ "$APPLY" == true ]]; then
      h="''${HOST_NAMES[0]}"
      IS_DARWIN="''${HOST_IS_DARWIN[0]}"
      LOCAL_HOSTNAME="$(hostname)"

      if [[ "$h" != "$LOCAL_HOSTNAME" ]]; then
        echo "error: --apply target '$h' does not match local hostname '$LOCAL_HOSTNAME'" >&2
        exit 1
      fi

      if [[ "$IS_DARWIN" == true ]]; then
        echo "Applying darwin configuration for $h..."
        sudo -E darwin-rebuild switch --flake ".#$h"
      else
        echo "Applying NixOS configuration for $h..."
        sudo nixos-rebuild switch --flake ".#$h"
      fi
    fi
  '';
}
