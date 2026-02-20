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
    [[ "$#" -ge 1 ]] \
      || { echo "usage: nix-flake-build [OPTIONS...] <HOST>..." >&2; exit 1; }

    OPTIONS=()
    HOST_NAMES=()

    for arg in "$@"; do
      if [[ "$arg" == -* ]]; then
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

    HOSTS=()
    for h in "''${HOST_NAMES[@]}"; do
      HOSTS+=(".#nixosConfigurations.$h.config.system.build.toplevel")
    done

    nom build --no-link --print-out-paths --show-trace ''${OPTIONS[@]} "''${HOSTS[@]}"
  '';
}
