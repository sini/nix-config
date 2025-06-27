{ inputs, rootPath, ... }:
{
  imports = [
    (
      {
        lib,
        flake-parts-lib,
        ...
      }:
      flake-parts-lib.mkTransposedPerSystemModule {
        name = "pkgs";
        file = ./pkgs.nix;
        option = lib.mkOption {
          type = lib.types.unspecified;
        };
      }
    )
  ];

  perSystem =
    { pkgs, system, ... }:
    {
      _module.args.pkgs = import inputs.nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
        overlays =
          builtins.attrValues (
            import (rootPath + "/overlays/default.nix") {
              inherit inputs;
            }
          )
          ++ [
            inputs.nix-topology.overlays.default
          ];
      };
      inherit pkgs;
    };
}
