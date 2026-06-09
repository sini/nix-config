# Reusable updater for the repo's custom packages (pkgs/by-name). Wraps
# nix-update, which fetches each package's source, rewrites version + source
# hash (and vendor/cargo hashes when building), and verifies the build.
#
#   update-pkgs                  # update every flake package (best effort)
#   update-pkgs foo bar          # update only the named packages
#   update-pkgs --no-build foo   # skip the post-update build
#   update-pkgs foo -- --version=branch=main   # pass extra flags to nix-update
#
# Packages in PINNED are skipped in all-packages mode (e.g. cni-plugin-cilium is
# held on a cilium pre-release; nix-update would downgrade it to latest stable).
# Name them explicitly with an appropriate --version to bump them anyway.
{
  writeShellApplication,
  nix-update,
  nix,
  jq,
}:
writeShellApplication {
  name = "update-pkgs";
  meta.description = "Update custom package sources via nix-update";
  runtimeInputs = [
    nix-update
    nix
    jq
  ];
  text = ''
    pinned=(
      cni-plugin-cilium
    )

    build=1
    targets=()
    extra=()

    while [[ $# -gt 0 ]]; do
      case "$1" in
        --no-build) build=0; shift ;;
        --) shift; extra=("$@"); break ;;
        -h | --help)
          echo "Usage: update-pkgs [--no-build] [PACKAGE...] [-- nix-update args]"
          exit 0
          ;;
        *) targets+=("$1"); shift ;;
      esac
    done

    all_mode=0
    if [[ ''${#targets[@]} -eq 0 ]]; then
      all_mode=1
      system=$(nix eval --raw --impure --expr builtins.currentSystem)
      mapfile -t targets < <(
        nix eval ".#packages.$system" --apply builtins.attrNames --json | jq -r '.[]'
      )
    fi

    args=(--flake)
    [[ $build -eq 1 ]] && args+=(--build)
    [[ ''${#extra[@]} -gt 0 ]] && args+=("''${extra[@]}")

    rc=0
    for pkg in "''${targets[@]}"; do
      if [[ $all_mode -eq 1 ]] && printf '%s\n' "''${pinned[@]}" | grep -qxF "$pkg"; then
        echo ">> $pkg: skipped (pinned)"
        continue
      fi
      echo ">> $pkg: updating"
      if ! nix-update "''${args[@]}" "$pkg"; then
        echo "   $pkg: no update applied (not updatable or already current)"
        [[ $all_mode -eq 0 ]] && rc=1
      fi
    done
    exit $rc
  '';
}
