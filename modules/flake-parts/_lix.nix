{
  inputs,
  rootPath,
  ...
}:
{
  # Lix wiring — DISABLED.
  #
  # This file is prefixed `_` so import-tree skips it: nothing here is collected,
  # so the `lix`/`lix-module` inputs vanish from the generated flake (run
  # `nix run .#write-flake` after toggling) and the fleet falls back to upstream
  # CppNix (nixpkgs default).
  #
  # Re-enable Lix:
  #   1. rename this file `_lix.nix` -> `lix.nix`
  #   2. re-add `core.nix.lix` to modules/den/aspects/roles/default.nix includes
  #      (the only edit outside this file — it sets nix.package = lix)
  #   3. `nix run .#write-flake` to regenerate flake.nix
  # The flake inputs, the lixPackageSets overlay, and colmena's lix-compatible
  # nix-eval-jobs all toggle automatically with this file.
  flake-file.inputs = {
    lix = {
      url = "github:lix-project/lix";
      flake = false;
    };

    lix-module = {
      url = "git+https://git@git.lix.systems/lix-project/nixos-module";
      inputs = {
        nixpkgs.follows = "nixpkgs-unstable";
        lix.follows = "lix";
      };
    };
  };

  # Force the lixPackageSets overlay onto the flake-level pkgs (otherwise built
  # lix-free in modules/flake-parts/pkgs.nix). mkForce overrides that module's
  # `_module.args.pkgs`; when this file is disabled the override disappears and
  # pkgs.nix's clean pkgs stands. colmena reads `pkgs.lixPackageSets` from here.
  # NOTE: the import below mirrors pkgs.nix — keep the config/overlays in sync.
  perSystem =
    { system, lib, ... }:
    {
      _module.args.pkgs = lib.mkForce (import inputs.nixpkgs-unstable {
        inherit system;
        config = {
          allowUnfree = true;
          allowDeprecatedx86_64Darwin = true;
        };
        overlays = [
          # lix-module first so lixPackageSets is available to later overlays
          inputs.lix-module.overlays.default
        ]
        ++ builtins.attrValues (import (rootPath + "/pkgs/overlays.nix") { inherit inputs; })
        ++ [
          inputs.nix-topology.overlays.default
        ];
      });
    };
}
