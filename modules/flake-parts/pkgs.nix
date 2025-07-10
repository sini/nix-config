{
  inputs,
  withSystem,
  rootPath,
  ...
}:
{
  imports = [
    inputs.pkgs-by-name-for-flake-parts.flakeModule
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
        config = {
          allowUnfreePredicate = _pkg: true;
        };
        overlays =
          builtins.attrValues (
            import (rootPath + "/pkgs/overlays.nix") {
              inherit inputs;
            }
          )
          ++ [
            inputs.nix-topology.overlays.default
          ];
      };
      pkgsDirectory = rootPath + "/pkgs/by-name";
      inherit pkgs;
    };

  flake = {
    overlays.default =
      _final: prev:
      withSystem prev.stdenv.hostPlatform.system (
        { config, ... }:
        {
          local = config.packages;
        }
      );
  };

}
