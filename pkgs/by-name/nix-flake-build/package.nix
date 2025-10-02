{
  writeShellApplication,
  nix-output-monitor,
}:
writeShellApplication {
  name = "nix-flake-build";
  runtimeInputs = [ nix-output-monitor ];
  text = ''
    [[ "$#" -ge 1 ]] \
      || { echo "usage: nix-flake-build <HOST>..." >&2; exit 1; }
    HOSTS=()
    for h in "$@"; do
      HOSTS+=(".#nixosConfigurations.$h.config.system.build.toplevel")
    done
    nom build --no-link --print-out-paths --show-trace "''${HOSTS[@]}"
  '';
}
