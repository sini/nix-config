{
  writeShellApplication,
  nix-output-monitor,
}:
writeShellApplication {
  name = "nix-flake-build";
  meta.description = "Build a host configuration";

  runtimeInputs = [ nix-output-monitor ];
  text = ''
    [[ "$#" -ge 1 ]] \
      || { echo "usage: nix-flake-build [OPTIONS...] <HOST>..." >&2; exit 1; }

    OPTIONS=()
    HOST_NAMES=()

    for arg in "$@"; do
      if [[ "$arg" == -* ]]; then
        OPTIONS+=("$arg")
      else
        HOST_NAMES+=("$arg")
      fi
    done

    [[ "''${#HOST_NAMES[@]}" -ge 1 ]] \
      || { echo "error: at least one HOST must be specified" >&2; exit 1; }

    HOSTS=()
    for h in "''${HOST_NAMES[@]}"; do
      HOSTS+=(".#nixosConfigurations.$h.config.system.build.toplevel")
    done

    nom build --no-link --print-out-paths --show-trace "''${OPTIONS[@]}" "''${HOSTS[@]}"
  '';
}
