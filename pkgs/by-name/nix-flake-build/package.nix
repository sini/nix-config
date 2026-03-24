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
      HOST_SYSTEM=$(nix eval --raw ".#hosts.$h.system" 2>/dev/null || echo "x86_64-linux")
      if [[ "$HOST_SYSTEM" == *darwin* ]]; then
        HOSTS+=(".#darwinConfigurations.$h.config.system.build.toplevel")
      else
        HOSTS+=(".#nixosConfigurations.$h.config.system.build.toplevel")
      fi
    done

    nom build --keep-going --no-link --print-out-paths --show-trace ''${OPTIONS[@]} "''${HOSTS[@]}"
  '';
}
