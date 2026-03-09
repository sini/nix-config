{
  writeShellApplication,
  nix-fast-build,
}:
writeShellApplication {
  name = "nix-flake-build";
  meta.description = "Build a host configuration";

  excludeShellChecks = [ "SC2068" ];

  runtimeInputs = [ nix-fast-build ];
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

    for h in "''${HOST_NAMES[@]}"; do
      HOST=".#nixosConfigurations.$h.config.system.build.toplevel"
      # --option keep-going --option no-link --option print-out-paths --option show-trace
      nix-fast-build --skip-cached --option accept-flake-config true ''${OPTIONS[@]} -f "$HOST"
    done

  '';
}
